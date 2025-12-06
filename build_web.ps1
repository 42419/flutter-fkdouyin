# Build Flutter Web
Write-Host "Building Flutter Web..."
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed"
    exit 1
}

# Run Hash Script
Write-Host "Applying Content Hashing..."
node tools/hash_web.js

if ($LASTEXITCODE -ne 0) {
    Write-Error "Content hashing failed"
    exit 1
}

Write-Host "Web build with content hashing completed successfully."
