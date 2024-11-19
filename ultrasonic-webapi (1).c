//https://script.googleusercontent.com/macros/echo?user_content_key=Krj5BYkxl2BAZDjQAeCFt5BnIIMm5N5tkbjNQ8S81LVINhb5gmwnP9TXolZhrD4uozj9_Lz1KSrrQXIjlUXJEcdBMoGhSbu3m5_BxDlH2jW0nuo2oDemN9CCS2h10ox_1xSncGQajx_ryfhECjZEnLDNFjpqJGOfWfZUEMMVSH_5fe-sIUJ7RN8WtjhzluYyDZ1ujWIp3WP3oof-sTnt6H_CLdAxJtHJipMZwBUHx2jt8qaJi70QHY20itk2Lave5BSdi74Y3nY&lib=M--LlTF6zXepeAj4zfLbfHUwZ7ki6rcAH

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>

// Ultrasonic sensor pin definitions
const int analogPin = A0;  // A0
const int echoPin = 5;  // D1
const int trigPin = 4;  // D2

// WiFi credentials
const char* ssid = "ssid";     // Your WiFi network name
const char* password = "secret";    // Your WiFi password

// Google Sheets settings
const char* host = "script.google.com";
const int httpsPort = 443;
WiFiClientSecure client;
String GAS_ID = "AKfycbyHmiDjNpL_-Wqw9Fm1_X7aTsNn1xa8h2IUF72O5J_Ke3suLm_C8lOE0QcMAUQOfnME";  // ID for your Google Apps Script

// Variables for ultrasonic sensor
long duration;
int distance;

// Variables for accelerometer
int acceleration;

void setup() {
  // Initialize Serial communication
  Serial.begin(115200);

  // Initialize ultrasonic sensor pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("Connected to WiFi");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Disable certificate verification for the secure client (for development purposes)
  client.setInsecure();
}

void loop() {
  // Trigger the ultrasonic sensor
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Read the echo pin and calculate the distance
  duration = pulseIn(echoPin, HIGH);
  distance = duration * 0.034 / 2;

  acceleration = analogRead(analogPin);
  
  // Print the distance to Serial Monitor
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" cm");
  
  // Print axis to serial monitor
  Serial.print("Acceleration: ");
  Serial.print(acceleration);

  // Send data to Google Sheets
  sendData(distance);
  sendData(acceleration);

  // If the distance is less than 3 cm, put the ESP to deep sleep
  if (distance < 2) {
    Serial.println("Going to deep sleep...");
    ESP.deepSleep(0);
  }

  delay(1000);  // Wait for 1 second before taking another measurement
}

// Subroutine to send distance data to Google Sheets
void sendData(int distance) {
  Serial.println("==========");
  Serial.print("Connecting to ");
  Serial.println(host);

  // Attempt to connect to Google
  if (!client.connect(host, httpsPort)) {
    Serial.println("Connection failed");
    return;
  }

  // Prepare the URL for the GET request to Google Apps Script
  String string_distance = String(distance);
  String string_acceleration = String(acceleration);
  String url = "/macros/s/" + GAS_ID + "/exec?distance=" + string_distance + "&acceleration=" + string_acceleration;

  Serial.print("Requesting URL: ");
  Serial.println(url);

  // Send HTTP request to Google
  client.print(String("GET ") + url + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" +
               "User-Agent: ESP8266\r\n" +
               "Connection: close\r\n\r\n");

  // Wait for the response
  while (client.connected()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") {
      Serial.println("Headers received");
      break;
    }
  }

  // Read the response from Google
  String line = client.readStringUntil('\n');
  if (line.startsWith("{\"state\":\"success\"")) {
    Serial.println("Data successfully sent to Google Sheets");
  } else {
    Serial.println("Failed to send data to Google Sheets");
  }

  // Close the connection
  Serial.println("Closing connection");
  Serial.println("==========");
}
