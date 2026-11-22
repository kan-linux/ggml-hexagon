import { type SvelteAST } from '../../../parser/ast.js';
import type { State } from '../index.js';
interface Params {
    component: SvelteAST.Component;
    filename?: string;
    state: State;
}
export declare function transformLegacyStory(params: Params): SvelteAST.Component;
export {};
