import type { SvelteAST } from '../../ast.js';
interface Params {
    node: SvelteAST.Attribute | undefined;
    filename?: string;
    component: SvelteAST.Component;
}
export declare function getStringValueFromAttribute(params: Params): any;
export declare function getArrayOfStringsValueFromAttribute(params: Params): string[];
export {};
