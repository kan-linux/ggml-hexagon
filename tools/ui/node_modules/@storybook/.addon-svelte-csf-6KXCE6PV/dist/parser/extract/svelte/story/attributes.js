export function extractStoryAttributesNodes(options) {
    const { attributes, component } = options;
    const results = {};
    for (const attributeNode of component.attributes) {
        if (attributeNode.type === 'Attribute' &&
            attributes.includes(attributeNode.name)) {
            results[attributeNode.name] = attributeNode;
        }
    }
    return results;
}
