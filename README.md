# Raven Oxygen (Roblox)
Source code for my Roblox OOP Oxygen System. If editing this for your own project please give me credit. Also open source the code if possible.

This system is meant for altitude oxygen supply simulation, doesn't contain any sounds and is a simple system to get you started.

## Setup
If using the Roblox Model, the steps are the same but you don't need to do steps 3 & 4.

1) Download the "src" folder.
2) Put the contents of each folder into the appropriate location in Roblox Studio. The directory names should be the same as in Roblox.
3) Create a `RemoteFunction` and place it in `ReplicatedStorage`.
4) Create a `ScreenGui` in `StarterGui` with the following layout, or download the Roblox model.
     Gui format:
    ```
       --Oxygen (ScreenGui with ResetOnSpawn set to false)
           |--Frame (Just a Frame set to the appropriate size)
                 |--FlowToggle (TextButton)
                 |--OxygenLevel (TextLabel)
    ```
5) Create parts for your givers and oxygen refills. You'll need to edit the `ServerLoad` script to implement your preferred method.

## Bugs
If you find a bug, feel free to create an issue or fix it yourself and create a pull request. Please comment your edits if you fix it and make sure the bug is in this source code and not due to edits you made.

Note: It's not guaranteed that I will fix bugs or edit this code in future.

## Other resources
[Roblox Model](https://create.roblox.com/store/asset/18457275060/Raven-Oxygen-System "Roblox Model")
