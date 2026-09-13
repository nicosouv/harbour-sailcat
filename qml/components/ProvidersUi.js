// Display data for the chat providers.
//
// The identifiers must stay in sync with src/providers.cpp; an id missing here
// simply falls back to the neutral colour of a custom endpoint.
// Not a .pragma library: qsTr() needs the QML context.

var COLORS = {
    "mistral":  "#ff7000",
    "scaleway": "#a855f7",
    "ovh":      "#4f9bff",
    "groq":     "#f55036",
    "custom":   "#90a4ae"
}

function color(providerId) {
    var c = COLORS[providerId]
    return c !== undefined ? c : COLORS["custom"]
}

// One glyph standing in for a logo: shipping the real ones would mean putting
// somebody else's trademark in the package, and they would fight the ambience.
function initial(providerId) {
    switch (providerId) {
    case "mistral":  return "M"
    case "scaleway": return "S"
    case "ovh":      return "O"
    case "groq":     return "G"
    default:         return "•"
    }
}
