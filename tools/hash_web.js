const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const BUILD_DIR = path.join(__dirname, '../build/web');
const MAIN_JS = 'main.dart.js';

function hashFile(filePath) {
  const fileBuffer = fs.readFileSync(filePath);
  const hashSum = crypto.createHash('md5');
  hashSum.update(fileBuffer);
  return hashSum.digest('hex').substring(0, 8);
}

function replaceInFile(filePath, searchValue, replaceValue) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  if (content.includes(searchValue)) {
    content = content.replace(new RegExp(searchValue.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), replaceValue);
    fs.writeFileSync(filePath, content);
    console.log(`Updated ${path.basename(filePath)}`);
  }
}

function main() {
  const mainJsPath = path.join(BUILD_DIR, MAIN_JS);

  if (!fs.existsSync(mainJsPath)) {
    console.error(`Error: ${MAIN_JS} not found in ${BUILD_DIR}`);
    console.log('Make sure to run "flutter build web" first.');
    process.exit(1);
  }

  const hash = hashFile(mainJsPath);
  const hashedMainJs = `main.${hash}.dart.js`;
  const hashedMainJsPath = path.join(BUILD_DIR, hashedMainJs);

  // Rename main.dart.js
  fs.renameSync(mainJsPath, hashedMainJsPath);
  console.log(`Renamed ${MAIN_JS} to ${hashedMainJs}`);

  // Update references
  const filesToUpdate = [
    'flutter_bootstrap.js',
    'index.html',
    'flutter_service_worker.js',
    'manifest.json'
  ];

  filesToUpdate.forEach(file => {
    replaceInFile(path.join(BUILD_DIR, file), MAIN_JS, hashedMainJs);
  });
  
  // Also update references in the hashed main.dart.js itself if it refers to itself (unlikely but possible in sourcemaps)
  // Usually not needed for main.dart.js content, but maybe for source maps.
  // If main.dart.js.map exists, we should rename it too?
  // Flutter web build usually produces main.dart.js.map
  
  const mapFile = `${MAIN_JS}.map`;
  const mapPath = path.join(BUILD_DIR, mapFile);
  if (fs.existsSync(mapPath)) {
      const hashedMapFile = `${hashedMainJs}.map`;
      const hashedMapPath = path.join(BUILD_DIR, hashedMapFile);
      fs.renameSync(mapPath, hashedMapPath);
      console.log(`Renamed ${mapFile} to ${hashedMapFile}`);
      
      // Update reference in main.dart.js (last line usually)
      // //# sourceMappingURL=main.dart.js.map
      replaceInFile(hashedMainJsPath, mapFile, hashedMapFile);
  }

  console.log('Content hashing completed successfully.');
}

main();
