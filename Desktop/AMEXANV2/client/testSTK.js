const axios = require('axios');

(async () => {
  try {
    const response = await axios.post(
      'https://backend.payhero.co.ke/api/v2/payments',
      {
        amount: 1,
        phone_number: '254793666825',       // Correct field name + international format
        channel_id: 3183,                   // Active PayHero channel
        provider: 'm-pesa',
        external_reference: 'test-appointment-001',
        customer_name: 'Chris Kaburu',
        description: 'AMEXAN test STK push',
        callback_url: 'https://amexanserver.onrender.com/api/payhero-callback',
      },
      {
        headers: {
          Authorization: 'Basic QTBKWHY0VVhlaVl4N1A4ZzhpdFA6ZWEzNVllSDhWcHpHeEoyUDNzN2VndTh5NnBHcVdRdWFjUjYyVjBKUQ==',
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('STK Push Response:', response.data);
  } catch (err) {
    if (err.response) console.error('PayHero Error:', err.response.data);
    else console.error('Error:', err.message);
  }
})();