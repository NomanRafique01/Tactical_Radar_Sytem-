
#include <Servo.h>

// ---------- Pins ----------
#define SDA_PIN    2
#define SCL_PIN    12
#define BUZZER_PIN 4
#define SERVO_PIN  9
#define TRIG_PIN   5
#define ECHO_PIN   6

// ---------- Settings ----------
const int ALERT_CM = 16;       // Detection range: 13 cm
const int RELEASE_CM = 19;     // Release distance: 15 cm
const int MAX_CM = 200;

const int SERVO_SPEED_MS = 20;

// ---------- Detection Filtering ----------
const int DETECT_CONFIRM_COUNT = 3;
const int CLEAR_CONFIRM_COUNT = 3;

int detectCount = 0;
int clearCount = 0;

bool objectDetected = false;

// ---------- Machine Gun Buzzer ----------
const int BUZZ_ON_MS = 45;
const int BUZZ_OFF_MS = 45;

unsigned long lastBuzzTime = 0;
bool buzzerState = false;

void updateBuzzer() {

  if (!objectDetected) {

    if (buzzerState) {
      digitalWrite(BUZZER_PIN, LOW);
      buzzerState = false;
    }

    return;
  }

  unsigned long now = millis();

  if (buzzerState && now - lastBuzzTime >= BUZZ_ON_MS) {

    digitalWrite(BUZZER_PIN, LOW);
    buzzerState = false;
    lastBuzzTime = now;

  }
  else if (!buzzerState && now - lastBuzzTime >= BUZZ_OFF_MS) {

    digitalWrite(BUZZER_PIN, HIGH);
    buzzerState = true;
    lastBuzzTime = now;
  }
}

// ---------- LCD ----------
#define BACKLIGHT 0x08
#define EN        0x04
#define RS        0x01

uint8_t lcdAddr = 0x27;
bool lcdAvailable = false;

void sdaHigh() {
  pinMode(SDA_PIN, INPUT_PULLUP);
}

void sdaLow() {
  pinMode(SDA_PIN, OUTPUT);
  digitalWrite(SDA_PIN, LOW);
}

void sclHigh() {
  pinMode(SCL_PIN, INPUT_PULLUP);
}

void sclLow() {
  pinMode(SCL_PIN, OUTPUT);
  digitalWrite(SCL_PIN, LOW);
}

// ---------- I2C ----------
void i2cStart() {

  sdaHigh();
  sclHigh();
  delayMicroseconds(10);

  sdaLow();
  delayMicroseconds(10);

  sclLow();
  delayMicroseconds(10);
}

void i2cStop() {

  sdaLow();
  delayMicroseconds(10);

  sclHigh();
  delayMicroseconds(10);

  sdaHigh();
  delayMicroseconds(10);
}

bool i2cWriteByte(uint8_t b) {

  for (uint8_t i = 0; i < 8; i++) {

    if (b & 0x80) {
      sdaHigh();
    } else {
      sdaLow();
    }

    delayMicroseconds(5);

    sclHigh();
    delayMicroseconds(10);

    sclLow();
    delayMicroseconds(5);

    b <<= 1;
  }

  sdaHigh();
  delayMicroseconds(5);

  sclHigh();
  delayMicroseconds(10);

  bool ack = (digitalRead(SDA_PIN) == LOW);

  sclLow();
  delayMicroseconds(5);

  return ack;
}

bool expanderWrite(uint8_t data) {

  if (!lcdAvailable) return false;

  i2cStart();

  bool ok = i2cWriteByte(lcdAddr << 1);

  if (ok) {
    i2cWriteByte(data | BACKLIGHT);
  }

  i2cStop();

  return ok;
}

void pulseEnable(uint8_t data) {

  expanderWrite(data | EN);

  delayMicroseconds(2);

  expanderWrite(data & ~EN);

  delayMicroseconds(100);
}

void write4(uint8_t nibble, bool rs) {

  uint8_t data = (nibble << 4) | (rs ? RS : 0);

  expanderWrite(data);

  pulseEnable(data);
}

void lcdSend(uint8_t v, bool rs) {

  write4(v >> 4, rs);
  write4(v & 0x0F, rs);
}

void lcdCommand(uint8_t c) {
  lcdSend(c, false);
}

void lcdPrint(const char *s) {

  while (*s) {
    lcdSend(*s++, true);
  }
}

void lcdSetCursor(uint8_t col, uint8_t row) {

  lcdCommand(0x80 | ((row ? 0x40 : 0x00) + col));
}

// ---------- Find LCD ----------
bool findLcd() {

  uint8_t addrs[] = {0x27, 0x3F};

  for (uint8_t i = 0; i < 2; i++) {

    lcdAddr = addrs[i];

    i2cStart();

    bool ok = i2cWriteByte(lcdAddr << 1);

    i2cStop();

    if (ok) return true;
  }

  return false;
}

// ---------- LCD Initialization ----------
void lcdInit() {

  delay(50);

  write4(0x03, false);
  delay(5);

  write4(0x03, false);
  delay(5);

  write4(0x03, false);
  delay(1);

  write4(0x02, false);
  delay(1);

  lcdCommand(0x28);
  lcdCommand(0x0C);

  lcdCommand(0x01);
  delay(3);

  lcdCommand(0x06);
}

// ---------- Ultrasonic Sensor ----------
int measureCm() {

  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);

  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);

  digitalWrite(TRIG_PIN, LOW);

  unsigned long us = pulseIn(ECHO_PIN, HIGH, 15000UL);

  if (us == 0) {
    return -1;
  }

  int cm = (int)(us * 0.0343 / 2.0);

  if (cm <= 0 || cm > MAX_CM) {
    return -1;
  }

  return cm;
}

// ---------- LCD Messages ----------
void showScanning() {

  if (!lcdAvailable) return;

  lcdSetCursor(0, 0);
  lcdPrint("                ");

  lcdSetCursor(0, 1);
  lcdPrint("                ");

  lcdSetCursor(0, 0);
  lcdPrint("  Scanning !!   ");
}

void showDetected() {

  if (!lcdAvailable) return;

  lcdSetCursor(0, 0);
  lcdPrint("                ");

  lcdSetCursor(0, 1);
  lcdPrint("                ");

  lcdSetCursor(0, 0);
  lcdPrint("    Object      ");

  lcdSetCursor(0, 1);
  lcdPrint("  Detected !!   ");
}

// ---------- Servo ----------
Servo radarServo;

int currentAngle = 0;
int stepDir = 1;

// ---------- Setup ----------
void setup() {

  Serial.begin(9600);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  // Initialize LCD
  lcdAvailable = findLcd();

  if (lcdAvailable) {

    lcdInit();

    lcdSetCursor(0, 0);
    lcdPrint("  Radar Ready!  ");

    delay(1500);

    showScanning();

  } else {

    Serial.println("LCD NOT FOUND!");
  }

  // Initialize Servo
  radarServo.attach(SERVO_PIN);

  radarServo.write(0);

  delay(800);
}

// ---------- Main Loop ----------
void loop() {

  // Update rapid-fire buzzer
  updateBuzzer();

  // =====================================
  // OBJECT DETECTED: HOLD SERVO
  // =====================================

  if (objectDetected) {

    radarServo.write(currentAngle);

    int cm = measureCm();

    Serial.print(currentAngle);
    Serial.print(",");
    Serial.println(cm);

    // Check if object disappeared
    if (cm < 0 || cm > RELEASE_CM) {

      clearCount++;

    } else {

      clearCount = 0;
    }

    // Confirm object disappearance
    if (clearCount >= CLEAR_CONFIRM_COUNT) {

      objectDetected = false;

      clearCount = 0;
      detectCount = 0;

      digitalWrite(BUZZER_PIN, LOW);
      buzzerState = false;

      showScanning();
    }

    delay(80);

    return;
  }

  // =====================================
  // NORMAL SERVO SCANNING
  // =====================================

  radarServo.write(currentAngle);

  delay(SERVO_SPEED_MS);

  int cm = measureCm();

  Serial.print(currentAngle);
  Serial.print(",");
  Serial.println(cm);

  // =====================================
  // DETECTION FILTER
  // =====================================

  if (cm > 0 && cm <= ALERT_CM) {

    detectCount++;

  } else {

    detectCount = 0;
  }

  // =====================================
  // CONFIRMED OBJECT DETECTION
  // =====================================

  if (detectCount >= DETECT_CONFIRM_COUNT) {

    objectDetected = true;

    clearCount = 0;
    detectCount = 0;

    // Hold servo at current angle
    radarServo.write(currentAngle);

    // Reset buzzer timing for immediate firing
    buzzerState = false;
    digitalWrite(BUZZER_PIN, LOW);
    lastBuzzTime = millis() - BUZZ_OFF_MS;

    // Display detection
    showDetected();

    return;
  }

  // =====================================
  // CONTINUE RADAR MOVEMENT
  // =====================================

  currentAngle += stepDir;

  if (currentAngle >= 180) {

    currentAngle = 180;
    stepDir = -1;
  }

  if (currentAngle <= 0) {

    currentAngle = 0;
    stepDir = 1;
  }
}
