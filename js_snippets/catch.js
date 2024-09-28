console.log(`[${err.row}:${err.col}]Runtime Error: ${err.message}`);
console.log("Stack trace:");
for (const entry of __lfjs_stack.reverse()) {
    console.log(`  [${entry.row}:${entry.col}] > ${entry.name}`);
}
