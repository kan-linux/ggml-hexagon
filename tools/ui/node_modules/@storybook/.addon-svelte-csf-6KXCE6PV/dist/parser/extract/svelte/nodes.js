import { extractModuleNodes } from './module-nodes.js';
import { extractFragmentNodes } from './fragment-nodes.js';
/**
 * Pick only required Svelte AST nodes for further usage in this addon.
 */
export async function extractSvelteASTNodes(params) {
    const { ast, filename } = params;
    const { module, fragment } = ast;
    const moduleNodes = await extractModuleNodes({ module, filename });
    const fragmentNodes = await extractFragmentNodes({
        fragment,
        filename,
        moduleNodes,
    });
    return {
        ...moduleNodes,
        ...fragmentNodes,
    };
}
