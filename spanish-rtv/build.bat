@echo off
cd /d "%~dp0"

echo packing...
"C:\Program Files\7-Zip\7z.exe" a -tzip "spanish-rtv.zip" * -xr!"*.bat" -xr!"*.zip" -xr!"*.vmz"

echo rename to .vmz...
if exist "spanish-rtv.vmz" del "spanish-rtv.vmz"
rename "spanish-rtv.zip" "spanish-rtv.vmz"

echo ready.
pause