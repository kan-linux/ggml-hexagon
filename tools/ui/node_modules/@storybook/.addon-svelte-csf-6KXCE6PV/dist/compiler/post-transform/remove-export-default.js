import { print } from 'esrap';
/**
 * We need to remove the default export from the code,
 * because Storybook internally expects export default `meta`.
 */
export function removeExportDefault(params) {
    const { code, nodes } = params;
    const { exportDefault, storiesFunctionDeclaration } = nodes;
    if (exportDefault.declaration.type === 'FunctionDeclaration') {
        const { start, end } = exportDefault;
        // NOTE: It updates code by removing `export default` from the stories function declaration.
        code.update(start, end, print(storiesFunctionDeclaration).code);
    }
    if (exportDefault.declaration.type === 'Identifier') {
        code.remove(exportDefault.start, exportDefault.end);
    }
}
