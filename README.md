# Simply Appe

Simply Appe is a custom theme for the ITGmania software, developed as an integration and mashup of four distinct reference themes:

* **Simply Love** (Original version)
* **Simply Love zmod** (developed by Zarzob and Zankoku)
* **In The Groove 2.1** (developed by Dando)
* **Simply Arcade** (developed by Viper)

The objective of this project is to combine the classic visual user interface of arcade cabinets with modern gameplay modifications and optimizations tailored for competitive play.

---

## Key Features

### 1. UI Style and Integration
* **Visual Interface**: The theme adopts the graphical style and user interface of *In The Groove 2.1*.
* **Modifications & QoL**: Gameplay options and quality-of-life optimization features from *Simply Love zmod* are fully incorporated, with some inspirations from *Simply Arcade*'s mods.
* **Custom Tweaks**: Targeted adjustments have been applied to menu layouts to enhance legibility and navigation flow.

### 2. Integrated FSR Management Module (FSR Manager)
The theme features a native Lua module (`FSR.lua`) that enables in-game interfacing with hardware-based **FSR (Force Sensitive Resistor)** pressure sensors.

* **Real-Time Monitoring**: Displays live pressure values across the four primary channels (Left, Down, Up, Right) utilizing graphical status bars and numeric indicators.
* **Dynamic Threshold Configuration**: Allows users to modify the activation point (threshold) of each individual sensor directly from the in-game interface. Values are configurable up to a maximum of 1023, adjusting in increments of 5 units.
* **Profile Management**: Supports rapid loading and switching between different sensitivity profiles stored on the server.
* **Network Architecture**: The system executes an initial HTTP `GET` request to retrieve default parameters and establishes a persistent **WebSocket** connection (`ws://localhost:5000/ws`) for low-latency, bidirectional data streaming.

---

## Requirements and Configuration

### Enabling Network Communications
To allow the Lua module to communicate with the local endpoint (port 5000), the host must be explicitly authorized within the ITGmania environment:

1. Locate and open the ITGmania `Preferences.ini` file.
2. Find the `HttpAllowHosts` configuration string.
3. Add `localhost` to the list of allowed hosts (e.g., `HttpAllowHosts=localhost`).

### Theme Installation
1. Clone or download this repository.
2. Place the project directory inside the ITGmania themes folder:
```bash
   ITGmania/Themes/Simply-Appe/
```

3. Launch the software, navigate to **Options > System Options**, and set **Simply Appe** as the active theme.

---

## Input Mapping (FSR Manager)

While the FSR module is active, navigation commands are dynamically remapped as detailed in the table below:
| Command | State: Menu Navigation | State: Threshold Editing | State: Profile Selection |
| --- | --- | --- | --- |
| **&LEFT; / &RIGHT;** | Navigate between menu buttons | Select target sensor channel (L, D, U, R) | *Inactive* |
| **&UP; / &DOWN;** | *Inactive* | Increment / Decrement threshold ($\pm5$) | Scroll through the profile list |
| **&START;** | Confirm action / Enter editing mode | Save threshold and transmit to server | Confirm and apply selected profile |
| **&BACK;** | Close module / Return to previous menu | Cancel current modifications | Close profile picker overlay |
---

## Credits and References

Acknowledgment is given to the authors of the original projects from which this mashup is derived:

* **Simply Love Team**: For the original Simply Love theme architecture.
* **Zarzob & Zankoku**: For developing the expanded features found in *Simply Love zmod*.
* **Dando**: For the visual design and UI concept of *In The Groove 2.1*.
* **Viper**: For general help with theming and some ideas 