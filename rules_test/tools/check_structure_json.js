const fs = require('fs');
const path = require('path');

function checkStructure(suiteJsonPath) {
  if (!fs.existsSync(suiteJsonPath)) {
    console.error(`ERROR: Suite JSON not found at ${suiteJsonPath}`);
    process.exit(1);
  }
  const raw = fs.readFileSync(suiteJsonPath, 'utf8');
  const data = JSON.parse(raw);

  let totalTests = 0;
  let maxDepth = 0;
  let failedTests = data.numFailedTests || 0;
  const topLevelDescribes = new Map();

  for (const testResult of data.testResults || []) {
    for (const assertion of testResult.assertionResults || []) {
      totalTests++;
      const ancestors = assertion.ancestorTitles || [];
      const depth = ancestors.length;
      if (depth > maxDepth) {
        maxDepth = depth;
      }
      // Step K1 requirement: requires ancestorTitles.length === 1 for EVERY test, exit 1 otherwise.
      if (depth !== 1) {
        console.error(`FAIL: Test "${assertion.title}" has ancestorTitles length ${depth} (expected exactly 1). Ancestors: ${JSON.stringify(ancestors)}`);
        process.exit(1);
      }
      const topDescribe = ancestors[0];
      topLevelDescribes.set(topDescribe, (topLevelDescribes.get(topDescribe) || 0) + 1);
    }
  }

  console.log(`MAX DEPTH: ${maxDepth}`);
  console.log(`TOP-LEVEL DESCRIBES:`);
  for (const [desc, count] of topLevelDescribes.entries()) {
    console.log(`  - ${desc}: ${count} tests`);
  }
  console.log(`TESTS: ${totalTests} PASSED: ${totalTests - failedTests} FAILED: ${failedTests}`);
  if (maxDepth === 1) {
    console.log(`REAL FILE: PASS`);
  } else {
    console.log(`REAL FILE: FAIL`);
    process.exit(1);
  }
}

const suitePath = process.argv[2] || 'docs/evidence/fix2b/K1_suite.json';
checkStructure(suitePath);
