//Yeah this is poorly commented...  I know... :/
//~Greg

byte player1[] = {
    255, 72, 0, 
    247, 3, 0, 
    255, 40, 0, 
    247, 4, 0, 
    255, 53, 0, 
    247, 5, 0, 
    255, 190, 0, 
    255, 70, 0, 
    253, 3, 0, 
    125, 113, 0, 
    189, 18, 0, 
    253, 15, 0, 
    252, 19, 0, 
    253, 20, 0, 
    125, 23, 0, 
    124, 16, 0, 
    125, 37, 0, 
    253, 1, 0, 
    189, 12, 0, 
    253, 10, 0, 
    255, 144, 0, 
    253, 2, 0, 
    125, 13, 0, 
    124, 12, 0, 
    125, 34, 0, 
    124, 43, 0, 
    125, 22, 0, 
    124, 17, 0, 
    125, 34, 0, 
    124, 65, 0, 
    125, 30, 0, 
    189, 14, 0, 
    188, 17, 0, 
    252, 4, 0, 
    253, 7, 0, 
    125, 30, 0, 
    189, 9, 0, 
    253, 46, 0, 
    125, 27, 0, 
    124, 15, 0, 
    125, 56, 0, 
    189, 16, 0, 
    188, 2, 0, 
    252, 12, 0, 
    253, 26, 0, 
    125, 18, 0, 
    253, 1, 0, 
    252, 10, 0, 
    188, 2, 0, 
    189, 7, 0, 
    253, 15, 0, 
    189, 3, 0, 
    188, 38, 0, 
    189, 2, 0, 
    253, 63, 0, 
    125, 10, 0, 
    124, 29, 0, 
    125, 58, 0, 
    124, 38, 0, 
    125, 1, 0, 
    127, 6, 0, 
    125, 8, 0, 
    127, 6, 0, 
    125, 20, 0, 
    127, 21, 0, 
    125, 9, 0, 
    127, 3, 0, 
    125, 7, 0, 
    127, 4, 0, 
    125, 8, 0, 
    127, 4, 0, 
    125, 9, 0, 
    127, 4, 0, 
    125, 19, 0, 
    127, 9, 0, 
    125, 7, 0, 
    127, 4, 0, 
    125, 7, 0, 
    127, 5, 0, 
    125, 6, 0, 
    127, 5, 0, 
    125, 9, 0, 
    127, 4, 0, 
    125, 6, 0, 
    127, 6, 0, 
    125, 10, 0, 
    127, 3, 0, 
    125, 10, 0, 
    127, 3, 0, 
    125, 42, 0, 
    124, 17, 0, 
    125, 21, 0, 
    124, 11, 0, 
    125, 22, 0, 
    124, 14, 0, 
    125, 64, 0, 
    124, 20, 0, 
    125, 14, 0, 
    124, 13, 0, 
    125, 46, 0, 
    124, 11, 0, 
    125, 20, 0, 
    127, 5, 0, 
    125, 7, 0, 
    127, 5, 0, 
    125, 5, 0, 
    127, 4, 0, 
    125, 30, 0, 
    124, 13, 0, 
    125, 23, 0, 
    124, 27, 0, 
    125, 12, 0, 
    124, 18, 0, 
    125, 32, 0, 
    124, 73, 0, 
    125, 1, 0, 
    253, 1, 0, 
    255, 47, 1
};

const int pinNESLatch = 2;
const int pinReset = 4;
const int pinSetState = 3;
const int pinDebugLatch = 5;

const int pinArray[] = {13, 12, 11, 10, 9, 8, 7, 6}; // Pins to write to

unsigned int numStates = 0;

volatile unsigned int currentState = 0;
volatile unsigned int framesLeft = 0;
volatile bool Complete = false;

//Used for debugging without hardware
unsigned long previousMillis = 0; 
//Used for debugging without hardware

void printPaddedBinary(int value, int numBits) {
  for (int i = numBits - 1; i >= 0; i--) {
    Serial.print((value >> i) & 1);
  }
}

void latchSignal(){
digitalWrite(pinDebugLatch, HIGH);
if (!Complete){
  if (framesLeft > 0){
    framesLeft--;
    //Serial.println(framesLeft);
    } else {
      //Next controller state
      //Serial.print("State:");
      //Serial.println(currentState);
      currentState++;
      Serial.print(currentState);
      Serial.print(": ");
      writeState();
      setFramesLeft();
      Serial.print(", ");
      Serial.print(framesLeft);
      Serial.println(" frames.");

      if (currentState < numStates){
        //This counts as one frame too!
        framesLeft--;
      } else {
        Serial.println("Done!");
        Complete = true;
        detachInterrupt(digitalPinToInterrupt(pinNESLatch));
      }
      
  }
 }
digitalWrite(pinDebugLatch, LOW);
}
void setFramesLeft(){
  //From the bytearray, calculate how many frames to hold the state and store it in framesLeft
  byte lsb = player1[(currentState * 3) + 1];
  byte msb = player1[(currentState * 3) + 2];
  framesLeft = lsb | (msb << 8);
}

void NESReset(){
  Serial.println("Resetting NES.");
  for (int i = 0; i < 8; i++) {
    digitalWrite(pinArray[i], LOW);
  }
  digitalWrite(pinSetState, LOW);
  digitalWrite(pinDebugLatch, LOW);
  digitalWrite(pinReset, HIGH);
  delay(3000);
  digitalWrite(pinReset, LOW);
  for (int i = 0; i < 8; i++) {
    digitalWrite(pinArray[i], HIGH);
  }
  digitalWrite(pinSetState, LOW);
  digitalWrite(pinSetState, HIGH);
}


void writeState(){
  for (int i = 0; i < 8; i++) {
    digitalWrite(pinArray[i], (player1[currentState * 3] >> i) & 1);
  }
  digitalWrite(pinSetState, LOW);
  digitalWrite(pinSetState, HIGH);
  printPaddedBinary(player1[currentState * 3], 8);
}

void setup() {
  Serial.begin(115200);

  for (int i = 0; i < 8; i++) {
    pinMode(pinArray[i], OUTPUT);
  }
  
  pinMode(pinNESLatch, INPUT);
  pinMode(pinSetState, OUTPUT);
  pinMode(pinReset,OUTPUT);
  pinMode(pinDebugLatch, OUTPUT);
  ArdNESinit();
}

void ArdNESinit(){
  currentState = 0;
  framesLeft = 0;
  Complete = false;

  Serial.println("");
  Serial.println("****************************");
  Serial.println("NES / Arduino  - Greg Strike");
  Serial.println("The Curious Place");
  Serial.println("youtube.com/@GregStrike");
  Serial.println("****************************");

  numStates = ((sizeof(player1)) / 3) - 1;
  Serial.print("Num States:");
  Serial.println(numStates);

  writeState();
  setFramesLeft();

  attachInterrupt(digitalPinToInterrupt(pinNESLatch), latchSignal, RISING);

  NESReset();

  Serial.println("Ready.");
  }

void loop() {  

  //unsigned long currentMillis = millis(); // Get the current time

  // Just for debuging without hardware
  //if (currentMillis - previousMillis >= 2) {  //16 is "close" to realtime.
  //  previousMillis = currentMillis;
  //  latchSignal();
  //}

  if (Complete == true){
        delay(20000);
        ArdNESinit();
  }

}
