// Display data for conversation categories.
//
// The identifiers must stay in sync with src/categories.cpp, which is what the
// model is asked to choose from and what the local classifier falls back to.
// Not a .pragma library: qsTr() needs the QML context.

var COLORS = {
    "code":          "#4fc3f7",
    "debugging":     "#ef5350",
    "devops":        "#7e57c2",
    "data":          "#26a69a",
    "design":        "#ec407a",
    "writing":       "#ba68c8",
    "translation":   "#4db6ac",
    "learning":      "#ffb74d",
    "research":      "#64b5f6",
    "math":          "#9575cd",
    "science":       "#4dd0e1",
    "business":      "#5c6bc0",
    "finance":       "#66bb6a",
    "career":        "#ff8a65",
    "legal":         "#8d6e63",
    "health":        "#e57373",
    "cooking":       "#ffa726",
    "travel":        "#29b6f6",
    "home":          "#a1887f",
    "gaming":        "#7986cb",
    "music":         "#f06292",
    "media":         "#b39ddb",
    "sports":        "#9ccc65",
    "relationships": "#f48fb1",
    "productivity":  "#26c6da",
    "ideas":         "#ffd54f",
    "practical":     "#aed581",
    "other":         "#90a4ae"
}

// Insertion order doubles as the order shown in pickers.
var IDS = [
    "code", "debugging", "devops", "data", "design",
    "writing", "translation", "learning", "research",
    "math", "science", "business", "finance", "career", "legal",
    "health", "cooking", "travel", "home",
    "gaming", "music", "media", "sports",
    "relationships", "productivity", "ideas", "practical", "other"
]

function all() {
    return IDS
}

function color(category) {
    var c = COLORS[category]
    return c !== undefined ? c : COLORS["other"]
}

function label(category) {
    switch (category) {
    case "code":          return qsTr("Code")
    case "debugging":     return qsTr("Debugging")
    case "devops":        return qsTr("DevOps")
    case "data":          return qsTr("Data")
    case "design":        return qsTr("Design")
    case "writing":       return qsTr("Writing")
    case "translation":   return qsTr("Translation")
    case "learning":      return qsTr("Learning")
    case "research":      return qsTr("Research")
    case "math":          return qsTr("Maths")
    case "science":       return qsTr("Science")
    case "business":      return qsTr("Business")
    case "finance":       return qsTr("Finance")
    case "career":        return qsTr("Career")
    case "legal":         return qsTr("Legal")
    case "health":        return qsTr("Health")
    case "cooking":       return qsTr("Cooking")
    case "travel":        return qsTr("Travel")
    case "home":          return qsTr("Home")
    case "gaming":        return qsTr("Gaming")
    case "music":         return qsTr("Music")
    case "media":         return qsTr("Books & Movies")
    case "sports":        return qsTr("Sports")
    case "relationships": return qsTr("Relationships")
    case "productivity":  return qsTr("Productivity")
    case "ideas":         return qsTr("Ideas")
    case "practical":     return qsTr("Practical")
    default:              return qsTr("Other")
    }
}
