import type { extractStoriesNodesFromExportDefaultFn } from '../../../parser/extract/compiled/stories.js';
import type { SvelteASTNodes, extractSvelteASTNodes } from '../../../parser/extract/svelte/nodes.js';
interface Params {
    nodes: {
        component: {
            svelte: SvelteASTNodes['storyComponents'][number];
            compiled: Awaited<ReturnType<typeof extractStoriesNodesFromExportDefaultFn>>[number];
        };
        svelte: Awaited<ReturnType<typeof extractSvelteASTNodes>>;
    };
    filename?: string;
    originalCode: string;
}
/**
 * Insert addon's internal object `__svelteCsf`
 * to `parameters` of every `<Story />` component **into the compiled code**.
 */
export declare function insertSvelteCSFToStoryParameters(params: Params): void;
export {};
