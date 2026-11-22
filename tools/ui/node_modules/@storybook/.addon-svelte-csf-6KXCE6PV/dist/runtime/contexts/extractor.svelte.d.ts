import { type ComponentProps } from 'svelte';
import type Story from '../Story.svelte';
import type { Cmp } from '../../types.js';
export interface StoriesExtractorContextProps<TCmp extends Cmp> {
    isExtracting: boolean;
    register: (storyCmpProps: ComponentProps<typeof Story<Record<string, any>, TCmp>>) => void;
}
declare function buildContext<TCmp extends Cmp>(storyCmpProps: StoriesExtractorContextProps<TCmp>): {
    readonly isExtracting: boolean;
    readonly register: (storyCmpProps: (Partial<import("../../types.js").StoryAnnotations<Record<string, any>, TCmp>> & {
        id?: never;
        name?: string;
        exportName?: string;
        autodocs?: never;
        source?: never;
    } & (({
        exportName: string;
    } | {
        name: string;
    }) & ({
        children?: import("svelte").Snippet<[]> | undefined;
        asChild?: boolean;
        template?: never;
    } | {
        children?: never;
        asChild?: never;
        template?: import("svelte").Snippet<[Record<string, any>, import("../../types.js").StoryContext<Record<string, any>>]> | undefined;
    }))) & {}) => void;
};
export type StoriesExtractorContext<TCmp extends Cmp> = ReturnType<typeof buildContext<TCmp>>;
export type StoriesRepository<TCmp extends Cmp> = {
    stories: Map<string, ComponentProps<typeof Story<Record<string, any>, TCmp>>>;
};
export declare function createStoriesExtractorContext<TCmp extends Cmp>(repository: StoriesRepository<TCmp>): void;
export declare function useStoriesExtractor<TCmp extends Cmp>(): {
    readonly isExtracting: boolean;
    readonly register: (storyCmpProps: (Partial<import("../../types.js").StoryAnnotations<Record<string, any>, TCmp>> & {
        id?: never;
        name?: string;
        exportName?: string;
        autodocs?: never;
        source?: never;
    } & (({
        exportName: string;
    } | {
        name: string;
    }) & ({
        children?: import("svelte").Snippet<[]> | undefined;
        asChild?: boolean;
        template?: never;
    } | {
        children?: never;
        asChild?: never;
        template?: import("svelte").Snippet<[Record<string, any>, import("../../types.js").StoryContext<Record<string, any>>]> | undefined;
    }))) & {}) => void;
};
export {};
