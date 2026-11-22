import type MagicString from 'magic-string';
import type { extractStoriesNodesFromExportDefaultFn } from '../../../parser/extract/compiled/stories.js';
import type { SvelteASTNodes } from '../../../parser/extract/svelte/nodes.js';
interface Params {
    code: MagicString;
    nodes: {
        component: {
            svelte: SvelteASTNodes['storyComponents'][number];
            compiled: Awaited<ReturnType<typeof extractStoriesNodesFromExportDefaultFn>>[number];
        };
        svelte: SvelteASTNodes;
    };
    filename?: string;
    originalCode: string;
}
/**
 * Transform compiled `<Story />` component when necessary,
 * and print updated AST node of compiled version to original raw source code {@link MagicString}.
 */
export declare function transformStory(params: Params): void;
export {};
