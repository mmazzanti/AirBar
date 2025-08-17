<h1>
  <img src="https://github.com/mmazzanti/AirBar/blob/2484037408380c42d051749009feea530ea3c478/Images/AirBar.png" alt="AirBar Logo" width="48" height="48" style="vertical-align:middle; margin-right:10px;">
  AirBar
</h1>


AirBar is a macOS app that displays air quality information directly in your Mac menu bar. It provides real-time monitoring of temperature, CO2, and PM2.5 values streamed from your AirGradient dashboard.

<p align="center">
  <img src="https://github.com/mmazzanti/AirBar/blob/0891add32d9f917e07e3efbc040297c2881d6277/Images/AirBar_pres.jpeg" width="45%" />
  <img src="https://github.com/mmazzanti/AirBar/blob/2484037408380c42d051749009feea530ea3c478/Images/airgradient-dashboard.png" width="45%" />
</p>

## Features

- Displays live temperature, CO2, and PM2.5 levels in the menu bar.
- Visual air quality status with colored indicators (🟢, 🟡, 🟠, 🔴).
- Shows charts of the past 6 hours of CO2 and PM2.5 values for detailed monitoring.
- Simple setup via your AirGradient API key and location ID.

## How to Use

1. **Get Your API Key**:  
   Visit [AirGradient Settings](https://app.airgradient.com/settings/place?tab=4) to obtain your API key and locate your Place ID.

2. **Configure the App**:  
   Set your AirGradient API key and location ID inside the app settings.

   ![Configuration Screen](https://github.com/mmazzanti/AirBar/blob/2484037408380c42d051749009feea530ea3c478/Images/configure.png)

3. **Start Monitoring**:  
   Once configured, AirBar will start pulling data and display your air quality status and historical charts.

## Air Quality Indicator

- 🟢 PM2.5 below 5 µg/m³ (Good)
- 🟡 PM2.5 between 5 and 29 µg/m³ (Moderate)
- 🟠 PM2.5 between 30 and 50 µg/m³ (Unhealthy for sensitive groups)
- 🔴 PM2.5 above 50 µg/m³ (Unhealthy)

## How to Open an Unsigned App or DMG

As I am not a registered Apple developer (99$/year are way too much for the amount I make out of my software 🙃) you will see a warning that the app is from an unidentified developer and it won’t open.

Follow these steps to allow it:

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Scroll down to the bottom where you see the **Security** section.
4. You should see a message saying the app was blocked from opening because it’s not from an identified developer.
5. Click the **Open Anyway** button.
6. Confirm you want to open the app in the next prompt.

This process is required since macOS now enforces stricter security for unsigned apps.

<img src="https://github.com/mmazzanti/AirBar/blob/9a248ebb5a2bc421821f275a493b0baf2c83344b/Images/non-registered-apple.png" alt="How to open unsigned app" width="50%">
