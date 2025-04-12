require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Resend } = require('resend'); // Correctly import Resend

const app = express();
app.use(cors());
app.use(express.json());

const resend = new Resend(process.env.RESEND_API_KEY); // Initialize Resend with API Key

// Function to generate OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

app.post('/send-otp', async (req, res) => {
    const { email } = req.body;

    // Validate email input
    if (!email) return res.status(400).json({ error: 'Email is required' });

    const otp = generateOTP(); // Generate OTP
    console.log(`OTP for ${email}: ${otp}`); // Log OTP for debugging

    try {
        // Log to confirm API key is loaded
        console.log('Resend API Key:', process.env.RESEND_API_KEY); 

        // Send OTP email using Resend
        await resend.emails.send({
            from: 'your_verified_email@example.com', // Ensure this is a verified email
            to: email,
            subject: 'Your OTP Code',
            text: `Your OTP code is ${otp}. It expires in 5 minutes.`,
        });

        res.json({ success: true, message: 'OTP sent successfully' });
    } catch (error) {
        console.error('Error sending OTP email:', error); // Detailed error log
        res.status(500).json({ error: error.message });
    }
});

app.listen(5000, () => console.log('Server running on port 5000'));
