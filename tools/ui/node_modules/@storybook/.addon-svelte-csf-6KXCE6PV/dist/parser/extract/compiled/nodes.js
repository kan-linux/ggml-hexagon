import pkg from '@storybook/addon-svelte-csf/package.json' with { type: 'json' };
import { MissingDefineMetaVariableDeclarationError, MissingImportedDefineMetaError, NoExportDefaultError, NoStoriesFunctionDeclarationError, NoStoryIdentifierFoundError, } from '../../../utils/error/parser/extract/compiled.js';
import { DefaultOrNamespaceImportUsedError } from '../../../utils/error/parser/extract/svelte.js';
const AST_NODES_NAMES = {
    defineMeta: 'defineMeta',
    Story: 'Story',
};
/**
 * Extract compiled AST nodes from Vite _(via `rollup`)_.
 * Those nodes are required for further code transformation.
 */
export async function extractCompiledASTNodes(params) {
    const { ast, filename } = params;
    const { walk } = await import('zimmerframe');
    const state = { potentialStoriesFunctionDeclaration: [] };
    const visitors = {
        ImportDeclaration(node, { state, visit }) {
            const { source, specifiers } = node;
            if (source.value === pkg.name) {
                for (const specifier of specifiers) {
                    if (specifier.type !== 'ImportSpecifier') {
                        throw new DefaultOrNamespaceImportUsedError(filename);
                    }
                    visit(specifier, state);
                }
            }
        },
        ImportSpecifier(node) {
            if (node.imported.name === AST_NODES_NAMES.defineMeta) {
                state.defineMetaImport = node;
            }
        },
        VariableDeclaration(node, { state }) {
            const { declarations } = node;
            const declaration = declarations[0];
            const { id, init } = declaration;
            if (id.type === 'ObjectPattern' &&
                init?.type === 'CallExpression' &&
                init.callee.type === 'Identifier' &&
                init.callee.name === state.defineMetaImport?.local.name) {
                state.defineMetaVariableDeclaration = node;
                for (const property of id.properties) {
                    if (property.type === 'Property' &&
                        property.key.type === 'Identifier' &&
                        property.key.name === AST_NODES_NAMES.Story &&
                        property.value.type === 'Identifier') {
                        state.storyIdentifier = property.value;
                    }
                }
            }
        },
        FunctionDeclaration(node, { state }) {
            state.potentialStoriesFunctionDeclaration.push(node);
        },
        ExportDefaultDeclaration(node, { state }) {
            state.exportDefault = node;
            if (node.declaration.type === 'FunctionDeclaration') {
                /*
                In production, Svelte will compile the component to:
                export default COMPONENT_NAME () {...}
                */
                state.storiesFunctionDeclaration = node.declaration;
            }
            else if (node.declaration.type === 'Identifier') {
                /*
                In development, Svelte will compile the component to:
                function COMPONENT_NAME () {...}
                export default COMPONENT_NAME;
                */
                const { name } = node.declaration;
                state.storiesFunctionDeclaration = state.potentialStoriesFunctionDeclaration?.find((potential) => potential.id.name === name);
            }
        },
    };
    walk(ast, state, visitors);
    const { defineMetaImport, defineMetaVariableDeclaration, exportDefault, storyIdentifier, storiesFunctionDeclaration, } = state;
    if (!defineMetaImport) {
        throw new MissingImportedDefineMetaError(filename);
    }
    if (!defineMetaVariableDeclaration) {
        throw new MissingDefineMetaVariableDeclarationError(filename);
    }
    if (!exportDefault) {
        throw new NoExportDefaultError(filename);
    }
    if (!storyIdentifier) {
        throw new NoStoryIdentifierFoundError(filename);
    }
    if (!storiesFunctionDeclaration) {
        throw new NoStoriesFunctionDeclarationError(filename);
    }
    return {
        defineMetaImport,
        defineMetaVariableDeclaration,
        exportDefault,
        storyIdentifier,
        storiesFunctionDeclaration,
    };
}
