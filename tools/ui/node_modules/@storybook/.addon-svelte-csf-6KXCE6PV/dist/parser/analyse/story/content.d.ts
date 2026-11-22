import type { SvelteAST } from '../../ast.js';
import type { extractSvelteASTNodes } from '../../extract/svelte/nodes.js';
interface Params {
    nodes: {
        component: SvelteAST.Component;
        svelte: Awaited<ReturnType<typeof extractSvelteASTNodes>>;
    };
    originalCode: string;
    filename?: string;
}
/**
 * Extract the source code of the `<Story />` component content (children or template snippet).
 * Reference: Step 2 from the comment: https://github.com/storybookjs/addon-svelte-csf/pull/181#issuecomment-2143539873
 */
export declare function getStoryContentRawCode(params: Params): string;
export {};
