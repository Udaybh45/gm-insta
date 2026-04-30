const dns = require('dns');
dns.lookup('cluster0.hdrstb7.mongodb.net', (err, address, family) => {
  console.log('address: %j family: %s', address, family);
  if (err) console.error('Error:', err);
});
