.pragma library

function localFilePath(url) {
  var value = String(url || "")
  if (value.indexOf("file://") === 0) value = value.slice(7)
  try {
    return decodeURIComponent(value)
  } catch (error) {
    return value
  }
}
