# **MRZ OCR Scanner for ID Cards**  

The **MRZ OCR Scanner** is a powerful iOS application that extracts **Machine Readable Zone (MRZ) data** from ID cards using **Apple's Vision framework**. This app utilizes **real-time OCR (Optical Character Recognition)** through the device’s camera to accurately detect and process MRZ information with high efficiency.

## **Technologies Used**  
- **Swift** – Native iOS development  
- **Vision Framework** – Advanced text recognition and OCR  
- **AVFoundation** – Camera access and video processing  
- **CoreImage & Accelerate** – Image enhancement for improved OCR performance  

## **How It Works**  
1. The user aligns their **ID card** within the designated frame.  
2. The app continuously scans for **MRZ patterns** (`<<<` symbols) in real-time.  
3. Once a stable MRZ is detected, the app extracts and processes the **ID number, surname, and given names**.  
4. The extracted MRZ data is displayed in a simple **popup alert**.  

