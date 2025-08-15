<table>
  <tr>
    <td><img src="https://github.com/mmazzanti/AirBar/blob/2484037408380c42d051749009feea530ea3c478/Images/AirBar.png" alt="AirBar Logo" width="64" height="64"></td>
    <td><h1>AirBar</h1></td>
  </tr>
</table>


AirBar is a macOS app that displays air quality information directly in your Mac menu bar. It provides real-time monitoring of temperature, CO2, and PM2.5 values streamed from your AirGradient dashboard.

![AirGradient Dashboard](https://github.com/mmazzanti/AirBar/blob/2484037408380c42d051749009feea530ea3c478/Images/airgradient-dashboard.png)

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

