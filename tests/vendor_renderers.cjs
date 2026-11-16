const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const classes = {};
const proxy = new Proxy(function(){}, {get: () => proxy});
const context = {
  gettext: x => x,
  Proxmox: { Utils: proxy },
  PVE: { Utils: proxy, mod: {TempHelper: {CELSIUS: 0, FAHRENHEIT: 1}}},
  Ext: {
    define(name, config) { classes[name] = config; },
    isNumber: x => typeof x === 'number' && !Number.isNaN(x),
    create(name, config) {
      const definition = classes[name];
      const instance = {...definition, self: definition.statics};
      definition.constructor.call(instance, config);
      return instance;
    },
    util: {Format: {number: (value) => String(value)}}
  }
};
vm.runInNewContext(fs.readFileSync(process.argv[2], 'utf8'), context);
const status = classes['PVE.node.StatusView'];
for (const id of ['upsc', 'thermalCpu', 'speedFan']) {
  assert.equal(status.items.filter(x=>x.itemId===id).length, 1, id);
}
const ups = status.items.find(x=>x.itemId==='upsc').renderer('device.model: Fixture UPS\nups.status: OL\nbattery.charge: 100\n');
assert(ups.includes('Fixture UPS'));
const sensors=fs.readFileSync(process.argv[3], 'utf8');
const cpu=status.items.find(x=>x.itemId==='thermalCpu').renderer(sensors);
assert(cpu.includes('40'),cpu);
console.log('Widgets registered once; CPU and UPS renderers passed');
