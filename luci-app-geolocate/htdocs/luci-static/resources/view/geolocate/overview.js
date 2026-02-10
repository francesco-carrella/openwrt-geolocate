'use strict';
'require view';
'require poll';
'require ui';
'require rpc';

var callInfo = rpc.declare({
	object: 'geolocate',
	method: 'info',
	expect: { '': {} }
});

var callScan = rpc.declare({
	object: 'geolocate',
	method: 'scan',
	expect: { '': {} }
});

return view.extend({
	_iframe: null,
	_mapReady: false,
	_pendingInfo: null,

	load: function() {
		return L.resolveDefault(callInfo(), {});
	},

	render: function(info) {
		info = info || {};
		var lat = parseFloat(info.latitude);
		var lon = parseFloat(info.longitude);
		var hasPosition = (!isNaN(lat) && !isNaN(lon));
		var isUnreliable = (info.source === 'ip');

		var posContent;
		if (hasPosition) {
			posContent = lat.toFixed(5) + ', ' + lon.toFixed(5);
			if (isUnreliable)
				posContent += ' (' + _('IP-based, unreliable') + ')';
		} else {
			posContent = E('em', { 'class': 'spinning' }, _('Collecting data…'));
		}

		var statusTable = E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, _('Position')),
				E('td', { 'class': 'td left', 'id': 'geo-position' }, posContent)
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('Accuracy')),
				E('td', { 'class': 'td left', 'id': 'geo-accuracy' },
					hasPosition ? this.fmtAccuracy(info.accuracy) : '-')
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('Source')),
				E('td', { 'class': 'td left', 'id': 'geo-source' },
					hasPosition ? (isUnreliable ? _('IP Geolocation (unreliable)') : (info.source || '-')) : '-')
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('Backend')),
				E('td', { 'class': 'td left', 'id': 'geo-backend' },
					info.backend || '-')
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('WiFi APs')),
				E('td', { 'class': 'td left', 'id': 'geo-wifi' },
					(info.wifi_aps !== undefined) ? String(info.wifi_aps) : '-')
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('Cell Towers')),
				E('td', { 'class': 'td left', 'id': 'geo-cell' },
					(info.cell_towers !== undefined) ? String(info.cell_towers) : '-')
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left' }, _('Last Update')),
				E('td', { 'class': 'td left', 'id': 'geo-age' }, [
					E('span', { 'id': 'geo-age-text' }, this.fmtAge(info.age)),
					' ',
					E('a', {
						'id': 'geo-scan-btn',
						'href': '#',
						'style': 'font-size:90%',
						'click': ui.createHandlerFn(this, 'handleScan')
					}, _('(refresh)'))
				])
			])
		]);

		var warningBanner = E('p', {
			'class': 'alert-message warning',
			'id': 'geo-warning',
			'style': isUnreliable ? '' : 'display:none'
		}, _('Position is based on IP geolocation and may be very inaccurate. ' +
			'Consider switching to Google Geolocation API or Unwired Labs in Settings.'));

		this._iframe = E('iframe', {
			'src': L.resource('geolocate/map.html'),
			'style': 'height:400px; width:100%; border:none; margin-bottom:1em;'
		});

		this._pendingInfo = hasPosition ? info : null;

		window.addEventListener('message', L.bind(function(ev) {
			if (ev.data && ev.data.type === 'mapReady') {
				this._mapReady = true;
				if (this._pendingInfo)
					this._postPosition(this._pendingInfo);
			}
		}, this));

		if (!this._pollFn) {
			this._pollFn = L.bind(this.pollStatus, this);
			poll.add(this._pollFn, 5);
		}

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Geolocate')),
			E('div', { 'class': 'cbi-map-descr' },
				_('WiFi and cell tower geolocation for your OpenWrt device.')),
			warningBanner,
			E('div', { 'class': 'cbi-section' }, [
				this._iframe,
				statusTable
			])
		]);
	},

	_postPosition: function(info) {
		if (!this._mapReady || !this._iframe || !this._iframe.contentWindow)
			return;

		this._iframe.contentWindow.postMessage({
			type: 'updatePosition',
			latitude: info.latitude,
			longitude: info.longitude,
			accuracy: info.accuracy,
			source: info.source
		}, '*');
	},

	handleScan: function(ev) {
		if (ev) ev.preventDefault();
		var link = document.getElementById('geo-scan-btn');
		if (link) {
			link.textContent = _('(scanning…)');
			link.style.pointerEvents = 'none';
		}

		return callScan().then(function() {
			window.setTimeout(function() {
				if (link) {
					link.textContent = _('(refresh)');
					link.style.pointerEvents = '';
				}
			}, 3000);
		}).catch(function() {
			if (link) {
				link.textContent = _('(refresh)');
				link.style.pointerEvents = '';
			}
		});
	},

	pollStatus: function() {
		return L.resolveDefault(callInfo(), {}).then(L.bind(function(info) {
			this.updateDisplay(info);
			this._pendingInfo = info;
			this._postPosition(info);
		}, this));
	},

	updateDisplay: function(info) {
		var isUnreliable = (info.source === 'ip');
		var lat = parseFloat(info.latitude);
		var lon = parseFloat(info.longitude);
		var hasPosition = (!isNaN(lat) && !isNaN(lon));

		var posEl = document.getElementById('geo-position');
		if (posEl && hasPosition) {
			posEl.textContent = lat.toFixed(5) + ', ' + lon.toFixed(5);
			posEl.style.fontStyle = '';
			posEl.style.color = isUnreliable ? '#d9534f' : '';
			if (isUnreliable)
				posEl.textContent += ' (' + _('IP-based, unreliable') + ')';
		}

		this.setText('geo-accuracy', hasPosition ? this.fmtAccuracy(info.accuracy) : '-');

		var srcEl = document.getElementById('geo-source');
		if (srcEl) {
			srcEl.textContent = hasPosition
				? (isUnreliable ? _('IP Geolocation (unreliable)') : (info.source || '-'))
				: '-';
			srcEl.style.color = isUnreliable ? '#d9534f' : '';
		}

		this.setText('geo-backend', info.backend || '-');
		this.setText('geo-wifi', (info.wifi_aps !== undefined) ? String(info.wifi_aps) : '-');
		this.setText('geo-cell', (info.cell_towers !== undefined) ? String(info.cell_towers) : '-');
		this.setText('geo-age-text', this.fmtAge(info.age));

		var warnEl = document.getElementById('geo-warning');
		if (warnEl)
			warnEl.style.display = isUnreliable ? '' : 'none';
	},

	setText: function(id, value) {
		var el = document.getElementById(id);
		if (el) el.textContent = value;
	},

	fmtAccuracy: function(acc) {
		acc = parseFloat(acc);
		if (isNaN(acc)) return '-';
		if (acc >= 10000) return '>' + Math.round(acc / 1000) + ' km';
		return Math.round(acc) + ' m';
	},

	fmtAge: function(age) {
		if (age === undefined || age === null) return '-';
		if (age < 60) return age + 's ' + _('ago');
		if (age < 3600) return Math.floor(age / 60) + 'm ' + _('ago');
		return Math.floor(age / 3600) + 'h ' + _('ago');
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
