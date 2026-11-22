import { createASTArrayExpression, createASTExportSpecifier, } from '../../../parser/ast.js';
export function createExportOrderVariableDeclaration(params) {
    const { storiesIdentifiers: storyIdentifiers } = params;
    const specifier = createASTExportSpecifier({ local: '__namedExportsOrder' });
    return {
        type: 'ExportNamedDeclaration',
        specifiers: [specifier],
        declaration: {
            type: 'VariableDeclaration',
            kind: 'const',
            declarations: [
                {
                    type: 'VariableDeclarator',
                    id: specifier.local,
                    init: createASTArrayExpression(storyIdentifiers.map(({ exportName }) => ({
                        type: 'Literal',
                        value: exportName,
                    }))),
                },
            ],
        },
    };
}
