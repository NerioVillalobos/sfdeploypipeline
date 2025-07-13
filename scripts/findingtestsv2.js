const fs = require('fs');
const path = require('path');

const APEX_CLASSES_DIR = 'force-app/main/default/classes';

function getApexClasses(directory) {
    return fs.readdirSync(directory)
        .filter(file => file.endsWith('.cls'))
        .filter(file => !/TEST|Test_|test_|_TEST|TEST_|Test|_test|TestData/i.test(file))
        .map(file => path.basename(file, '.cls'));
}

function getTestClasses(directory) {
    const regex = /TEST|Test_|test_|_TEST|TEST_|Test|_test/;
    return fs.readdirSync(directory)
        .filter(file => file.endsWith('.cls') && regex.test(file))
        .map(file => path.basename(file, '.cls'));
}

function getClassContent(directory, className) {
    const filePath = path.join(directory, `${className}.cls`);
    return fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : '';
}

function findTestReferences(apexClass, testClassContent) {
    const patterns = [
        new RegExp(`\\bnew\\s+${apexClass}\\b`, 'g'),
        new RegExp(`\\b${apexClass}\\.\\w+\\(`, 'g'),
        new RegExp(`\\b${apexClass}\\s+\\w+;`, 'g')
    ];
    return patterns.some(pattern => pattern.test(testClassContent));
}

function findPrimaryTestClass(apexClass, testClasses) {
    let bestMatch = null;
    let maxScore = 0;
    let possibleMatches = [];

    for (const testClass of testClasses) {
        const testClassContent = getClassContent(APEX_CLASSES_DIR, testClass);
        let score = 0;

        // Priorizar coincidencias exactas con el nombre + 'Test'
        if (testClass === `${apexClass}Test`) {
            return testClass;
        }

        if (testClassContent.includes(apexClass)) {
            score += 3;
        }
        if (findTestReferences(apexClass, testClassContent)) {
            score += 2;
        }

        if (score > 0) {
            possibleMatches.push({ testClass, score });
        }
    }

    if (possibleMatches.length > 0) {
        possibleMatches.sort((a, b) => b.score - a.score);
        bestMatch = possibleMatches[0].testClass;
    }

    return bestMatch;
}

function mapApexToTests() {
    const apexClasses = getApexClasses(APEX_CLASSES_DIR);
    const testClasses = getTestClasses(APEX_CLASSES_DIR);
    let mapping = {};

    for (const apexClass of apexClasses) {
        const primaryTestClass = findPrimaryTestClass(apexClass, testClasses);
        mapping[apexClass] = primaryTestClass ? primaryTestClass : '❌ No tiene pruebas asociadas';
    }
    return mapping;
}

const testClassMap = mapApexToTests();
console.log("Lista de ApexClass con sus respectivas ApexTest:");
Object.entries(testClassMap).forEach(([apexClass, testClass]) => {
    console.log(` ${apexClass} → ${testClass}`);
});
