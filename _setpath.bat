@echo off
setlocal
echo === Setting JAVA_HOME ===
reg add "HKCU\Environment" /v JAVA_HOME /t REG_SZ /d "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot" /f
echo.
echo === Updating USER Path ===
reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "C:\Users\Lenovo\AppData\Local\Programs\Python\Python312\Scripts\;C:\Users\Lenovo\AppData\Local\Programs\Python\Python312\;C:\Users\Lenovo\AppData\Local\Programs\Python\Launcher\;%%USERPROFILE%%\AppData\Local\Microsoft\WindowsApps;%%USERPROFILE%%\.local\bin;C:\Users\Lenovo\AppData\Roaming\npm;C:\Users\Lenovo\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin;C:\Users\Lenovo\AppData\Local\Programs\Microsoft VS Code\bin;C:\src\flutter\bin;%%JAVA_HOME%%\bin" /f
echo.
echo === Broadcasting WM_SETTINGCHANGE so new shells pick it up ===
echo (No native broadcaster from cmd; new cmd/Explorer windows will see it.)
echo DONE
endlocal
