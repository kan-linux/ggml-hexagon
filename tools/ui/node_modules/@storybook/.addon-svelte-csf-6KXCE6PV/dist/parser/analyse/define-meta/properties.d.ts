import type { ESTreeAST } from '../../ast.js';
interface GetStringOptions {
    node: ESTreeAST.Property;
    filename: string;
}
export declare function getPropertyStringValue(options: GetStringOptions): string;
interface GetArrayOfStringOptions {
    node: ESTreeAST.Property;
    filename: string;
}
export declare function getPropertyArrayOfStringsValue(options: GetArrayOfStringOptions): string[];
export {};
