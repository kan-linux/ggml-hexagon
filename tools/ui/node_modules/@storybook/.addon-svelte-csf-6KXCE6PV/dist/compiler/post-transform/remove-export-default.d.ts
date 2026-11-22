import type MagicString from 'magic-string';
import type { CompiledASTNodes } from '../../parser/extract/compiled/nodes.js';
interface Params {
    code: MagicString;
    nodes: CompiledASTNodes;
    filename?: string;
}
/**
 * We need to remove the default export from the code,
 * because Storybook internally expects export default `meta`.
 */
export declare function removeExportDefault(params: Params): void;
export {};
