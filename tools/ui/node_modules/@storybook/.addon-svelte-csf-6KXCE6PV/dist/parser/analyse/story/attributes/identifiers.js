import { getStringValueFromAttribute } from '../attributes.js';
import { extractStoryAttributesNodes } from '../../../extract/svelte/story/attributes.js';
import { isValidVariableName, storyNameToExportName } from '../../../../utils/identifier-utils.js';
import { DuplicateStoryIdentifiersError, InvalidStoryExportNameError, NoStoryIdentifierError, } from '../../../../utils/error/parser/analyse/story.js';
export function getStoryIdentifiers(options) {
    const { nameNode, exportNameNode, filename, component } = options;
    let exportName = getStringValueFromAttribute({
        node: exportNameNode,
        filename,
        component,
    });
    const name = getStringValueFromAttribute({
        node: nameNode,
        filename,
        component,
    });
    if (!exportName) {
        if (!name) {
            throw new NoStoryIdentifierError({
                component,
                filename,
            });
        }
        exportName = storyNameToExportName(name);
    }
    if (!isValidVariableName(exportName)) {
        throw new InvalidStoryExportNameError({
            filename,
            component,
            value: exportName,
        });
    }
    return {
        name,
        exportName,
    };
}
export function getStoriesIdentifiers(params) {
    const { nodes, filename } = params;
    const { storyComponents } = nodes;
    const allIdentifiers = [];
    for (const story of storyComponents) {
        const { exportName, name } = extractStoryAttributesNodes({
            component: story.component,
            filename,
            attributes: ['exportName', 'name'],
        });
        const identifiers = getStoryIdentifiers({
            exportNameNode: exportName,
            nameNode: name,
            filename,
            component: story.component,
        });
        const duplicateIdentifiers = allIdentifiers.find((existingIdentifiers) => existingIdentifiers.exportName === identifiers.exportName);
        if (duplicateIdentifiers) {
            throw new DuplicateStoryIdentifiersError({
                filename,
                identifiers,
                duplicateIdentifiers,
            });
        }
        allIdentifiers.push(identifiers);
    }
    return allIdentifiers;
}
