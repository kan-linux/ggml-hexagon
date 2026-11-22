import { StorybookSvelteCSFError } from '../../../error.js';
import type { extractStoriesNodesFromExportDefaultFn } from '../../../../parser/extract/compiled/stories.js';
export declare class MissingImportedDefineMetaError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 1;
    readonly documentation = true;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class MissingDefineMetaVariableDeclarationError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 2;
    readonly documentation = true;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class NoExportDefaultError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 3;
    readonly documentation = true;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class NoStoryIdentifierFoundError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 4;
    readonly documentation = true;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class NoStoriesFunctionDeclarationError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 5;
    readonly documentation = true;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class NoCompiledStoryPropsObjectExpression extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_COMPILED";
    readonly code = 6;
    readonly documentation = true;
    node: Awaited<ReturnType<typeof extractStoriesNodesFromExportDefaultFn>>[number];
    constructor({ filename, node, }: {
        filename: StorybookSvelteCSFError['filename'];
        node: NoCompiledStoryPropsObjectExpression['node'];
    });
    template(): string;
}
