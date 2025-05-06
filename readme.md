# Nyagra Slot Processing Sketch

A Processing sketch project with VSCode integration.

## Prerequisites

1. Install [Processing](https://processing.org/download)
2. Install [VSCode](https://code.visualstudio.com/)
3. Install the following VSCode extensions:
   - Processing Language Support
   - Java Extension Pack

## Setup

1. Make sure Processing is installed and the `processing-java` command is in your PATH
2. Clone this repository
3. Open the project in VSCode
4. Install the recommended extensions when prompted

## Running the Sketch

You can run the sketch in two ways:

1. Using VSCode Tasks:

   - Press `Cmd+Shift+B` (Mac) or `Ctrl+Shift+B` (Windows/Linux)
   - Or select "Run Build Task" from the Command Palette

2. Using Processing IDE:
   - Open the `nyagra_slot` folder in Processing IDE
   - Click the Run button

## Debugging

To debug the sketch:

1. Set breakpoints in your code
2. Press F5 or select "Start Debugging" from the Run menu
3. The sketch will run in debug mode

## Project Structure

- `nyagra_slot/nyagra_slot.pde`: Main sketch file
- `.vscode/`: VSCode configuration files
  - `tasks.json`: Build and run tasks
  - `launch.json`: Debug configuration
  - `settings.json`: VSCode settings
