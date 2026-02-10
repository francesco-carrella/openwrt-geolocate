'use strict';
'require view';
'require poll';
'require ui';
'require uci';
'require rpc';

var callOutputStatus = rpc.declare({
	object: 'geolocate',
	method: 'output_status',
	expect: { '': {} }
});

/* ── Integration definitions ─────────────────────────────────── */

var integrations = [
	{
		section: 'output_traccar',
		title: 'Traccar',
		type: 'output',
		fields: [
			{ key: 'url', label: 'Server URL', hint: 'Include port. Traccar OsmAnd listener default is 5055.', placeholder: 'http://traccar.example.com:5055' },
			{ key: 'device_id', label: 'Device Identifier', hint: 'Must match the identifier configured in Traccar.', placeholder: 'openwrt-router' }
		]
	},
	{
		section: 'output_owntracks',
		title: 'OwnTracks',
		type: 'output',
		fields: [
			{ key: 'url', label: 'Recorder URL', hint: 'Base URL of OwnTracks Recorder without /pub path.', placeholder: 'https://recorder.example.com' },
			{ key: 'username', label: 'Username' },
			{ key: 'device', label: 'Device Name', placeholder: 'router' },
			{ key: 'password', label: 'Password', password: true },
			{ key: 'tid', label: 'Tracker ID', hint: 'Two characters. Defaults to first two letters of device name.', placeholder: 'MV' }
		]
	},
	{
		section: 'output_dawarich',
		title: 'Dawarich',
		type: 'output',
		fields: [
			{ key: 'url', label: 'Dawarich URL', hint: 'Base URL without /api/v1/… path.', placeholder: 'https://dawarich.example.com' },
			{ key: 'api_key', label: 'API Key', hint: 'Found in Dawarich Account settings.', password: true }
		]
	},
	{
		section: 'output_ha',
		title: 'Home Assistant',
		type: 'output',
		fields: [
			{ key: 'ha_url', label: 'Home Assistant URL', placeholder: 'http://192.168.1.100:8123' },
			{ key: 'access_token', label: 'Long-Lived Access Token', hint: 'Create under HA Profile → Long-Lived Access Tokens. Used once for device registration.', password: true },
			{ key: 'webhook_id', label: 'Webhook ID', hint: 'Auto-populated after first successful registration. Do not edit.', readonly: true }
		]
	},
	{
		section: 'output_webhook',
		title: 'Webhook',
		type: 'output',
		fields: [
			{ key: 'url', label: 'Webhook URL', placeholder: 'https://example.com/webhook' },
			{ key: 'device_id', label: 'Device ID', hint: 'Identifies this device to the receiver.', placeholder: 'openwrt-router' },
			{ key: 'method', label: 'HTTP Method', select: ['POST', 'PUT'] },
			{ key: 'header_name', label: 'Auth Header', hint: 'e.g. Authorization, X-API-Key', placeholder: 'Authorization' },
			{ key: 'header_value', label: 'Auth Value', hint: 'e.g. Bearer your-token-here', placeholder: 'Bearer ...', password: true }
		]
	}
];

/* ── View ────────────────────────────────────────────────────── */

return view.extend({
	_statusData: {},

	load: function() {
		return Promise.all([
			uci.load('geolocate'),
			L.resolveDefault(callOutputStatus(), {})
		]);
	},

	render: function(data) {
		this._statusData = data[1] || {};

		var cards = integrations.map(L.bind(function(integ) {
			return this.renderCard(integ);
		}, this));

		var saveBtn = E('button', {
			'class': 'btn cbi-button cbi-button-apply',
			'click': ui.createHandlerFn(this, 'doSaveApply')
		}, _('Save & Apply'));

		if (!this._pollFn) {
			this._pollFn = L.bind(this.pollStatus, this);
			poll.add(this._pollFn, 10);
		}

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Geolocate Trackers')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Forward your position to tracking and location history services.')),
			E('div', {}, cards),
			E('div', { 'class': 'cbi-page-actions' }, [
				E('div', { 'class': 'right' }, saveBtn)
			])
		]);
	},

	renderCard: function(integ) {
		var section = integ.section;
		var enableKey = integ.enableKey || 'enabled';
		var enabled = uci.get('geolocate', section, enableKey) === '1';
		var status = this._statusData[section];

		var borderColor = this.getBorderColor(enabled, status);

		var card = E('div', {
			'class': 'cbi-section',
			'data-section': section,
			'style': 'border-left: 4px solid ' + borderColor + '; margin-bottom: 1em; padding: 1em;'
		});

		/* ── Header row: title + status badge ── */
		var headerChildren = [
			E('strong', { 'style': 'font-size: 1.1em;' }, integ.title)
		];

		if (!enabled) {
			headerChildren.push(E('span', {
				'style': 'color: #999; margin-left: 0.5em; font-size: 0.9em;'
			}, '(' + _('disabled') + ')'));
		}

		var badge = this.renderBadge(enabled, status);
		if (badge) {
			headerChildren.push(badge);
		}

		card.appendChild(E('div', {
			'style': 'display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.5em;'
		}, headerChildren));

		/* ── Description (if any) ── */
		if (integ.description) {
			card.appendChild(E('div', {
				'class': 'cbi-section-descr',
				'style': 'margin-bottom: 0.75em;'
			}, integ.description));
		}

		/* ── Enable toggle ── */
		var enableCb = E('input', {
			'type': 'checkbox',
			'checked': enabled ? '' : null,
			'data-section': section,
			'data-key': enableKey,
			'click': L.bind(function(integ, ev) {
				var checked = ev.target.checked;
				uci.set('geolocate', integ.section, integ.enableKey || 'enabled', checked ? '1' : '0');
				this.toggleFields(integ.section, checked);
			}, this, integ)
		});
		if (enabled) enableCb.checked = true;

		card.appendChild(E('div', { 'style': 'margin-bottom: 0.75em;' }, [
			E('label', { 'style': 'cursor: pointer;' }, [
				enableCb,
				E('span', { 'style': 'margin-left: 0.5em;' }, _('Enable'))
			])
		]));

		/* ── Fields container ── */
		var fieldsDiv = E('div', {
			'data-fields': section,
			'style': enabled ? '' : 'display:none;'
		});

		integ.fields.forEach(L.bind(function(field) {
			fieldsDiv.appendChild(this.renderField(section, field));
		}, this));

		card.appendChild(fieldsDiv);

		return card;
	},

	renderField: function(section, field) {
		var currentVal = uci.get('geolocate', section, field.key) || '';

		var row = E('div', {
			'class': 'cbi-value',
			'style': 'margin-bottom: 0.5em;'
		});

		var label = E('label', {
			'class': 'cbi-value-title',
			'style': 'display: inline-block; width: 200px; padding-top: 0.3em;'
		}, _(field.label));

		row.appendChild(label);

		var inputWrap = E('div', {
			'class': 'cbi-value-field',
			'style': 'display: inline-block;'
		});

		if (field.select) {
			var sel = E('select', {
				'class': 'cbi-input-select',
				'data-section': section,
				'data-key': field.key,
				'change': L.bind(function(section, key, ev) {
					uci.set('geolocate', section, key, ev.target.value);
				}, this, section, field.key)
			});
			field.select.forEach(function(val) {
				var opt = E('option', { 'value': val }, val);
				if (val === currentVal) opt.selected = true;
				sel.appendChild(opt);
			});
			inputWrap.appendChild(sel);
		} else {
			var input = E('input', {
				'type': field.password ? 'password' : 'text',
				'class': 'cbi-input-text',
				'value': currentVal,
				'placeholder': field.placeholder || '',
				'data-section': section,
				'data-key': field.key,
				'change': L.bind(function(section, key, ev) {
					uci.set('geolocate', section, key, ev.target.value);
				}, this, section, field.key)
			});
			if (field.readonly) {
				input.readOnly = true;
				input.style.opacity = '0.7';
			}
			inputWrap.appendChild(input);
		}

		if (field.hint) {
			inputWrap.appendChild(E('div', {
				'class': 'cbi-value-description',
				'style': 'font-size: 0.85em; color: #888; margin-top: 0.2em;'
			}, _(field.hint)));
		}

		row.appendChild(inputWrap);
		return row;
	},

	renderBadge: function(enabled, status) {
		if (!enabled) return null;

		var text, color, bgColor;
		if (!status) {
			text = _('Pending');
			color = '#8a6d3b';
			bgColor = '#fcf8e3';
		} else {
			var age = Math.floor(Date.now() / 1000) - status.timestamp;
			if (status.status === 'ok') {
				text = _('OK') + ' (' + this.fmtAge(age) + ')';
				color = '#3c763d';
				bgColor = '#dff0d8';
			} else {
				text = _('Error') + ' (' + this.fmtAge(age) + ')';
				color = '#a94442';
				bgColor = '#f2dede';
			}
		}

		return E('span', {
			'data-badge': 'true',
			'style': 'padding: 2px 8px; border-radius: 3px; font-size: 0.85em; ' +
				'color: ' + color + '; background: ' + bgColor + ';'
		}, text);
	},

	getBorderColor: function(enabled, status) {
		if (!enabled) return '#ccc';
		if (!status) return '#f0ad4e';
		if (status.status === 'ok') return '#5cb85c';
		return '#d9534f';
	},

	toggleFields: function(section, show) {
		var fieldsDiv = document.querySelector('[data-fields="' + section + '"]');
		if (fieldsDiv)
			fieldsDiv.style.display = show ? '' : 'none';

		/* Update card border to gray when disabled */
		var card = document.querySelector('[data-section="' + section + '"]');
		if (card)
			card.style.borderLeftColor = show ? '#f0ad4e' : '#ccc';

		/* Update header disabled label */
		var header = card ? card.querySelector('strong') : null;
		if (header) {
			var disabledLabel = header.nextElementSibling;
			if (!show && (!disabledLabel || disabledLabel.dataset.badge)) {
				var lbl = E('span', {
					'style': 'color: #999; margin-left: 0.5em; font-size: 0.9em;'
				}, '(' + _('disabled') + ')');
				header.parentNode.insertBefore(lbl, header.nextSibling);
			} else if (show && disabledLabel && !disabledLabel.dataset.badge) {
				disabledLabel.remove();
			}
		}

		/* Remove badge when disabled */
		if (!show && card) {
			var badge = card.querySelector('[data-badge]');
			if (badge) badge.remove();
		}
	},

	pollStatus: function() {
		return L.resolveDefault(callOutputStatus(), {}).then(L.bind(function(data) {
			this._statusData = data;
			this.updateAllCards();
		}, this));
	},

	updateAllCards: function() {
		integrations.forEach(L.bind(function(integ) {
			var section = integ.section;
			var enableKey = integ.enableKey || 'enabled';
			var card = document.querySelector('[data-section="' + section + '"]');
			if (!card) return;

			var enabled = uci.get('geolocate', section, enableKey) === '1';
			var status = this._statusData[section];
			var borderColor = this.getBorderColor(enabled, status);
			card.style.borderLeftColor = borderColor;

			/* Update badge */
			var oldBadge = card.querySelector('[data-badge]');
			if (oldBadge) oldBadge.remove();

			var newBadge = this.renderBadge(enabled, status);
			if (newBadge) {
				var header = card.querySelector('div');
				if (header) header.appendChild(newBadge);
			}
		}, this));
	},

	doSaveApply: function() {
		return uci.save().then(function() {
			return uci.apply();
		}).then(function() {
			return uci.load('geolocate');
		}).then(function() {
			ui.addNotification(null, E('p', _('Configuration saved and applied.')), 'info');
		}).catch(function(err) {
			ui.addNotification(null, E('p', _('Failed to save: ') + (err && err.message ? err.message : err)), 'danger');
		});
	},

	fmtAge: function(age) {
		if (age === undefined || age === null || isNaN(age)) return '';
		if (age < 0) age = 0;
		if (age < 60) return age + 's ' + _('ago');
		if (age < 3600) return Math.floor(age / 60) + 'm ' + _('ago');
		return Math.floor(age / 3600) + 'h ' + _('ago');
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
