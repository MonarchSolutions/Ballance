# Ballance

[Chinese Readmre](./README.md)

## Introduction

This is an open source unity remake of ballance game

Ballance unity rebuild is a small dream of the author. I hope that ballance can run on more platforms, can make levels easier, make modules for expanding functions (the latter has been developed by [ballancemodloader](https://github.com/Gamepiaynmo/BallanceModLoader).

This project is completely open source. You can compile, modify and expand the content of the game by yourself.

The project has completed the features of the original version:

* Original game content
* Level 1-13 game content
* Physical effect similarity 85%

Compared with the original version, this project has added the following features:

* **Load NMO files directly** (Windows version only)
* Android version, Mac version (You can also try to compile other platforms)
* Self made map interface
* Lua module, modul interface (Use Lua to develop mod or custom modules)
* Level previewer
* Mod manager

![image](/Assets/System/Textures/splash_app.bmp)

---

## Document

[Full Document](https://imengyu.github.io/Ballance/#/readme)

[API documentation](https://imengyu.github.io/Ballance/#/LuaApi/readme)

## System requirements

Minimum requirements

* Windows 7+
* MacOS High Sierra 10.13+ (Intel)
* Android 6.0+

||Minimum|Recommended|
|---|---|---|
|Processor|Quad core 3Ghz+|Dual core 3Ghz+|
|Memory|1 GB RAM|2 GB RAM|
|Graphics card|DirectX 10.1 capable GPU with 512 MB VRAM - GeForce GTX 260, Radeon HD 4850 or Intel HD Graphics 5500|DirectX 11 capable GPU with 2 GB VRAM - GeForce GTX 750 Ti, Radeon R7 360|
|DirectX|11|11|
|Storage space|60 MB free space|100 MB free space|

## Installation steps

1. Goto [Releases](https://github.com/imengyu/Ballance/releases) find the latest version.
2. Download the corresponding zip installation package.
3. Unzip all files, then run `ballance.exe` to start the game.

## Directly load NMO file [new]

Ballance Unity Rebuild Version 0.9.8 supports the function of loading the original level file of ballance.

You can load a standard original ballance NMO level by clicking start > Load original ballance NMO level.

The core uses the Virtools SDK 5.0 to process NMO files, so only the windows 32-bit version is supported.

Most levels can be loaded successfully and played, but there are a few restrictions:

* Cannot load level with Virtools script.
* Point and line mesh of Virtools are not supported.
* The material does not support the special effect of Virtools. The default material will be used instead.

## Turn on debugging mode

When running in unity editor, it is always debug mode.

### If you need to turn on the debugging mode of standalone version, you can

1. Go to the about menu, click the version number several times until the prompt pops up.
2. Then restart the game, you enter the debugging mode.
3. You can press F12 to open the console.

In the debugging mode, you can press the Q key to raise the ball and the e key to lower the ball.

Enter the `quit dev` command on the console to turn off the debugging mode.

### Open all original levels

After entering the debugging mode, you can enter `highscore open-all` command in the console to open all levels.

### How to run project source code

You need:

* Install Unity 2021.2.3+
* Install a code editor (VScode or Visual Studio)
* Clone or download this project `https://github.com/imengyu/Ballance` to your computer.

Steps:

1. Open the project with unity.
2. When running for the first time, you need to click the menu "Slua > All > Make" to generate Lua interface files. After generation, you don't need generate again.
3. Open `Scenes/MainScene.unity` scene.
4. Select the `GameEntry` object, set `Debug Type` to `NoDebug` in the inspector.
5. Click Run and you can see the game.

## Game album

Original levels

![Demo](docs/DemoImages/11.jpg)
![Demo](docs/DemoImages/12.jpg)
![Demo](docs/DemoImages/13.jpg)
![Demo](docs/DemoImages/14.jpg)
![Demo](docs/DemoImages/18.jpg)
![Demo](docs/DemoImages/9.jpg)
![Demo](docs/DemoImages/6.jpg)
![Demo](docs/DemoImages/7.jpg)
![Demo](docs/DemoImages/15.jpg)
![Demo](docs/DemoImages/16.jpg)
![Demo](docs/DemoImages/17.jpg)

Level 13

![Demo](docs/DemoImages/9.gif)
![Demo](docs/DemoImages/10.png)

Self made level (魔脓空间站)

![Demo](docs/DemoImages/3.jpg)
![Demo](docs/DemoImages/4.jpg)
![Demo](docs/DemoImages/5.jpg)

Level previewer

![Demo](docs/DemoImages/8.jpg)
![Demo](docs/DemoImages/1.jpg)
![Demo](docs/DemoImages/2.jpg)