const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// ⚠️ Use a real email and app password (not Gmail password)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "shanelvmi@gmail.com",         // ⬅️ Replace with sender email
    pass: "admin123",            // ⬅️ Replace with Gmail App Password
  },
});

exports.sendAssistantCredentials = functions.https.onCall(async (data, context) => {
  const { email, name, phone, password } = data;

  const mailOptions = {
    from: "VetBiz Admin <your-email@gmail.com>",
    to: email,
    subject: "VetBiz Assistant Login Credentials",
    text: `Hello ${name},

You have been registered as an assistant on the VetBiz system.

📧 Email: ${email}
📱 Phone: ${phone}
🔐 Password: ${password}

Please log in using these credentials and change your password after logging in.

Thank you,
VetBiz Admin Team`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error("Email send error:", error);
    throw new functions.https.HttpsError("internal", "Email sending failed");
  }
});
