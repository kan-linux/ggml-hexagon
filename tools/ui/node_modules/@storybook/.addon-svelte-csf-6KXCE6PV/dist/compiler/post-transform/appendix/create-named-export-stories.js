import { STORYBOOK_INTERNAL_PREFIX } from '../../../constants.js';
import { createASTIdentifier } from '../../../parser/ast.js';
export function createNamedExportStories(params) {
    return {
        type: 'ExportNamedDeclaration',
        specifiers: params.storiesIdentifiers.map(createExportSpecifier),
        declaration: null,
    };
}
function createExportSpecifier(storyIdentifier) {
    return {
        type: 'ExportSpecifier',
        local: createASTIdentifier(`${STORYBOOK_INTERNAL_PREFIX}${storyIdentifier.exportName}`),
        exported: createASTIdentifier(storyIdentifier.exportName),
    };
}
