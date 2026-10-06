# Empile - URLs Setup Guide

## 🌐 Required URLs for App Store Submission

For Apple's review process, you need working URLs for privacy policy and support. Here's how to set them up.

---

## 1. Privacy Policy URL

### Current Placeholder
```
https://example.com/empile/privacy
```

### What You Need to Do

#### Option A: Host on Your Own Website (Recommended)
1. Create or update your website
2. Add a page at `/empile/privacy`
3. Copy content from `PrivacyPolicy.txt` in this folder
4. Ensure HTTPS (not HTTP)
5. Test the URL works and loads properly

#### Option B: Use a Free Hosting Service
1. GitHub Pages: Create `privacy.html` in your repo
2. Netlify: Deploy a simple HTML page
3. Firebase Hosting: Free tier available
4. Vercel: Free for static sites

#### Example HTML for Privacy Policy
```html
<!DOCTYPE html>
<html>
<head>
    <title>Empile Privacy Policy</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; line-height: 1.6; }
        h1, h2 { color: #333; }
        a { color: #0066cc; }
    </style>
</head>
<body>
    <h1>Empile - Privacy Policy</h1>
    <!-- Copy content from PrivacyPolicy.txt here -->
</body>
</html>
```

**⚠️ Important**: 
- Privacy policy must be **publicly accessible** 
- Must be **in English** (at least)
- Must stay online forever
- Must load within a few seconds
- Do NOT change or remove it after submission

---

## 2. Support URL

### Current Placeholder
```
https://example.com/empile/support
```

### What You Need to Do

#### Option A: Create a Support Page
1. Add a page at `/empile/support`
2. Include:
   - Email: `empile.support@example.com`
   - Contact form (optional)
   - FAQ about the game
   - Troubleshooting tips

#### Example Support Page
```html
<!DOCTYPE html>
<html>
<head>
    <title>Empile - Support</title>
</head>
<body>
    <h1>Empile Support</h1>
    
    <h2>Need Help?</h2>
    <p>Email us: <a href="mailto:empile.support@example.com">empile.support@example.com</a></p>
    
    <h2>FAQ</h2>
    <ul>
        <li>How do I rotate blocks? Hold the block and tap with a second finger</li>
        <li>Can I play offline? Yes, fully playable without internet</li>
        <li>How do I reset my score? Delete and reinstall the app</li>
    </ul>
    
    <h2>Feedback</h2>
    <p>Love the game? Rate us on the App Store!</p>
    <p>Found a bug? Tell us at empile.support@example.com</p>
</body>
</html>
```

#### Option B: Link to Email
Simplest option - just link to email:
```html
<a href="mailto:empile.support@example.com">Contact Support</a>
```

**⚠️ Important**:
- Support email **must** be monitored
- **Respond within 48 hours** to support requests
- Keep this page updated
- Don't disable this after launch

---

## 3. Marketing URL (Optional)

### Current Placeholder
```
https://example.com/empile
```

### What You Need to Do

Create an optional marketing page:
- Screenshots of the game
- Description
- Download links
- Links to social media
- Game features
- System requirements

**This is optional** - Apple doesn't require it, but it's good to have.

---

## 🚀 Quick Setup (5 minutes)

### Using GitHub Pages (Free)

1. **Create GitHub Pages site** (if you don't have one)
   ```bash
   git clone https://github.com/yourusername/yourusername.github.io
   cd yourusername.github.io
   ```

2. **Create privacy policy**
   ```bash
   mkdir -p empile
   touch empile/privacy.html
   # Edit and add HTML content
   ```

3. **Create support page**
   ```bash
   touch empile/support.html
   # Edit and add HTML content
   ```

4. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Add Empile privacy and support pages"
   git push
   ```

5. **URL will be**:
   - `https://yourusername.github.io/empile/privacy.html`
   - `https://yourusername.github.io/empile/support.html`

---

## 4. Email Setup

### Support Email

You need an **actual, monitored email address**.

#### Option A: Create New Email
1. Create `empile.support@gmail.com` or similar
2. Set up email forwarding to your main email
3. Auto-responder: "We'll respond within 24 hours"

#### Option B: Use Existing Email
1. Use your company email
2. Create a filter: label emails from public as "Empile Support"
3. Auto-responder: "Thanks for contacting Empile support..."

#### Auto-Responder Template
```
Subject: We received your message

Hi there,

Thanks for contacting Empile support! We usually respond within 24 hours.

In the meantime, check out our support page for FAQs and troubleshooting:
https://example.com/empile/support

Best,
The Empile Team
```

---

## 5. Before You Submit to Apple

### Checklist
- [ ] Privacy Policy URL loads and works
- [ ] Privacy Policy is in English
- [ ] Privacy Policy matches PrivacyPolicy.txt
- [ ] Support email is monitored
- [ ] Support URL loads and works
- [ ] Both URLs use HTTPS (not HTTP)
- [ ] URLs are permanent (won't change)
- [ ] Pages load quickly (< 3 seconds)
- [ ] No 404 errors
- [ ] Tested on mobile browser

### Test URLs
```bash
# Test privacy policy
curl -I https://example.com/empile/privacy

# Test support page  
curl -I https://example.com/empile/support

# Should return: HTTP/1.1 200 OK
```

---

## 6. After Approval

### Maintenance
- ✅ Keep privacy policy updated
- ✅ Monitor support email daily
- ✅ Keep support page current
- ✅ Update links if you change domains
- ✅ Never delete these pages

### Do NOT
- ❌ Change or remove privacy policy
- ❌ Let support email bounce
- ❌ Move URLs without redirects
- ❌ Let pages expire
- ❌ Use HTTP instead of HTTPS

---

## 📝 What to Put in Support Page

### Essentials
- Contact email
- Response time promise
- FAQ section
- Game help/tips
- Bug reporting instructions

### Nice to Have
- Screenshot gallery
- Video tutorial links
- Social media links
- Feedback form
- Community forum

### Example Structure
```
# Empile Support

## Quick Help
- How to play
- Tips for beginners
- Controls & gestures

## Contact Us
Email: empile.support@example.com
(We respond within 24 hours)

## FAQ
Q: How do I rotate blocks?
A: Hold the block and tap with a second finger

Q: Can I play offline?
A: Yes, fully playable offline

## Feedback
Love the game? ⭐ Rate us!
Found a bug? 🐛 Tell us!
```

---

## 🔒 Security Notes

- Use **HTTPS only** (not HTTP)
- Keep email account secure
- Use strong password for email
- Enable 2FA on email account
- Don't share support email
- Monitor for spam

---

## ⏰ Timeline

1. **This week**: Set up URLs and email
2. **Tomorrow**: Test all links work
3. **Next week**: Submit to App Store
4. **2-5 days**: Apple reviews
5. **Day X**: Approved and available

---

## 💡 Pro Tips

1. **Auto-forward support emails** to your main email
2. **Use email templates** for quick responses
3. **Track support requests** in a simple spreadsheet
4. **Respond quickly** - Apple values responsive developers
5. **Keep pages simple** - users on mobile need fast loading
6. **Use HTTPS** - Apple requires it, users expect it

---

## 🆘 Troubleshooting

### "Privacy policy URL returns 404"
- [ ] Check URL spelling
- [ ] Verify page exists on server
- [ ] Test on mobile browser
- [ ] Check HTTPS works

### "Support email not responding"
- [ ] Check email account is active
- [ ] Check it's not going to spam
- [ ] Test sending from another email
- [ ] Set up email forwarding

### "URLs are too slow"
- [ ] Minimize HTML/CSS size
- [ ] Use CDN or fast hosting
- [ ] Remove unnecessary images
- [ ] Test with slow connection

---

## Final Reminders

✅ **Do:**
- Use real, accessible URLs
- Monitor support email
- Keep content updated
- Use HTTPS always
- Respond to users professionally

❌ **Don't:**
- Use fake/placeholder URLs
- Ignore support emails
- Change URLs after launch
- Leave HTTP instead of HTTPS
- Abandon support after approval

---

**Ready?** Once URLs are set up, update `AppStoreMetadata.md` with your actual URLs and proceed to submission!
