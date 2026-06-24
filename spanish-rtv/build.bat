@echo off
cd /d "%~dp0"

echo packing...
"C:\Program Files\7-Zip\7z.exe" a -tzip "spanish_rtv.zip" * -xr!"*.bat" -xr!"*.zip" -xr!"*.vmz"

echo rename to .vmz...
if exist "spanish_rtv.vmz" del "spanish_rtv.vmz"
rename "spanish_rtv.zip" "spanish_rtv.vmz"

echo ready.
pause