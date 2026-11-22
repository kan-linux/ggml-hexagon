import { DefaultOrNamespaceImportUsedError } from '../../../utils/error/parser/extract/svelte.js';
/**
 *
 * Codemod to transform AST node of {@link ImportDeclaration} specifiers.
 *
 * @example
 * ```diff
 * import {
 * - Story,
 * - Template,
 * + defineMeta,
 * } from "@storybook/addon-svelte-csf";
 * ```
 */
export function transformImportDeclaration(params) {
    const { node, filename } = params;
    let { specifiers, ...rest } = node;
    let newSpecifiers = [];
    let hasDefineMeta = false;
    for (const specifier of specifiers) {
        if (specifier.type !== 'ImportSpecifier') {
            throw new DefaultOrNamespaceImportUsedError(filename);
        }
        if (specifier.imported.name === 'defineMeta') {
            newSpecifiers.push(specifier);
            hasDefineMeta = true;
        }
    }
    if (!hasDefineMeta) {
        const imported = {
            type: 'Identifier',
            name: 'defineMeta',
        };
        newSpecifiers.push({
            type: 'ImportSpecifier',
            imported,
            local: imported,
        });
    }
    return {
        ...rest,
        specifiers: newSpecifiers,
    };
}
