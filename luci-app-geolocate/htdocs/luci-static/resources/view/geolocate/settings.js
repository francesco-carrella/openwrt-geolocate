'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('geolocate', _('Geolocate Settings'),
			_('Configure WiFi and cell tower geolocation.'));

		s = m.section(form.NamedSection, 'main', 'geolocate');

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.ListValue, 'interval', _('Scan Interval'));
		o.value('60', _('1 minute'));
		o.value('300', _('5 minutes'));
		o.value('600', _('10 minutes'));
		o.value('1800', _('30 minutes'));
		o.value('3600', _('1 hour'));
		o.default = '300';

		// ── Backend ─────────────────────────────────────────────────

		s = m.section(form.NamedSection, 'backend', 'backend', _('Location Provider'));
		s.description = _('Service used to resolve scanned data into coordinates.');

		o = s.option(form.ListValue, 'type', _('Service'));
		o.value('beacondb', _('BeaconDB (free, no key needed)'));
		o.value('google', _('Google Geolocation API'));
		o.value('unwiredlabs', _('Unwired Labs'));
		o.value('custom', _('Custom MLS-compatible endpoint'));
		o.default = 'beacondb';

		o = s.option(form.Value, 'google_api_key', _('API Key'));
		o.depends('type', 'google');
		o.password = true;
		o.rmempty = true;

		o = s.option(form.Value, 'unwiredlabs_api_key', _('API Key'));
		o.depends('type', 'unwiredlabs');
		o.password = true;
		o.rmempty = true;

		o = s.option(form.Value, 'custom_api_key', _('API Key'));
		o.depends('type', 'custom');
		o.password = true;
		o.rmempty = true;

		o = s.option(form.Value, 'custom_url', _('Endpoint URL'));
		o.depends('type', 'custom');
		o.placeholder = 'https://example.com/v1/geolocate';

		// ── Scanning ────────────────────────────────────────────────

		s = m.section(form.NamedSection, 'scanning', 'scanning', _('Scanning'));
		s.tab('wifi', _('WiFi'));
		s.tab('cell', _('Cell'));

		o = s.taboption('wifi', form.Flag, 'wifi_enabled', _('WiFi Scanning'));
		o.default = '1';

		o = s.taboption('wifi', form.Value, 'wifi_radio', _('Radio Interface'),
			_('Network interface used for WiFi scanning.'));
		o.depends('wifi_enabled', '1');
		o.default = 'wlan0';
		o.placeholder = 'wlan0';

		o = s.taboption('wifi', form.Value, 'wifi_min_aps', _('Minimum APs'),
			_('Minimum access points required for a query. Below this threshold, falls back to cell-only.'));
		o.depends('wifi_enabled', '1');
		o.default = '2';
		o.datatype = 'uinteger';

		o = s.taboption('wifi', form.Flag, 'nomap_filter', _('Filter _nomap SSIDs'),
			_('Exclude networks with _nomap in their SSID. Industry-standard opt-out.'));
		o.depends('wifi_enabled', '1');
		o.default = '1';

		o = s.taboption('cell', form.Flag, 'cell_enabled', _('Cell Tower Scanning'));
		o.default = '1';

		o = s.taboption('cell', form.ListValue, 'cell_method', _('Modem Interface'),
			_('Auto-detect tries gl_modem, then ModemManager — using whichever is installed.'));
		o.depends('cell_enabled', '1');
		o.value('auto', _('Auto-detect'));
		o.value('gl_modem_at', _('gl_modem AT (GL.iNet)'));
		o.value('mmcli', _('ModemManager (MBIM/QMI/AT)'));
		o.default = 'auto';

		return m.render();
	}
});
