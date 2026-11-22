import { type Snippet } from 'svelte';
import type { Cmp, StoryAnnotations, StoryContext } from '../../types.js';
interface ContextProps<TCmp extends Cmp> {
    currentStoryExportName: string | undefined;
    args: NonNullable<StoryAnnotations<Record<string, any>, TCmp>['args']>;
    storyContext: StoryContext<TCmp>;
    metaRenderSnippet?: Snippet<[
        StoryAnnotations<Record<string, any>, TCmp>['args'],
        StoryContext<TCmp>
    ]>;
}
declare function buildContext<TCmp extends Cmp>(props: ContextProps<TCmp>): {
    readonly args: Partial<Record<string, any>>;
    readonly storyContext: StoryContext<TCmp>;
    readonly currentStoryExportName: string | undefined;
    readonly metaRenderSnippet: Snippet<[Partial<Record<string, any>> | undefined, StoryContext<TCmp>]> | undefined;
    set: (props: ContextProps<TCmp>) => void;
};
export type StoryRendererContext<TCmp extends Cmp = Cmp> = ReturnType<typeof buildContext<TCmp>>;
export declare function useStoryRenderer<TCmp extends Cmp>(): {
    readonly args: Partial<Record<string, any>>;
    readonly storyContext: StoryContext<TCmp>;
    readonly currentStoryExportName: string | undefined;
    readonly metaRenderSnippet: Snippet<[Partial<Record<string, any>> | undefined, StoryContext<TCmp>]> | undefined;
    set: (props: ContextProps<TCmp>) => void;
};
export {};
