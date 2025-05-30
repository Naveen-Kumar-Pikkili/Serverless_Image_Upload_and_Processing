async function uploadImage() {
  const input = document.getElementById("imageInput");
  const file = input.files[0];
  const message = document.getElementById("message");

  if (!file) {
    message.textContent = "Please select an image.";
    return;
  }

  const allowedTypes = ['image/png', 'image/jpeg'];
  if (!allowedTypes.includes(file.type)) {
    message.textContent = "Only PNG and JPEG images are allowed.";
    return;
  }

  // Read file and convert to base64
  const reader = new FileReader();
  reader.onload = async function () {
    const base64Data = reader.result.split(',')[1]; // Remove data URI prefix

    try {
      const response = await fetch("https://xtan1pw3jl.execute-api.us-east-1.amazonaws.com/prod/upload", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "file-name": file.name
        },
        body: JSON.stringify({
          isBase64Encoded: true,
          body: base64Data
        })
      });

      const result = await response.json();
      if (response.ok) {
        message.textContent = "Upload successful: " + result.message;
      } else {
        message.textContent = "Error: " + result.message;
      }
    } catch (err) {
      message.textContent = "Upload failed: " + err.message;
    }
  };

  reader.readAsDataURL(file); // Reads as base64
}
