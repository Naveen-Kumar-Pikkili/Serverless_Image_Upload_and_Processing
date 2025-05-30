async function uploadImage() {
  const fileInput = document.getElementById("imageInput");
  const file = fileInput.files[0];
  const message = document.getElementById("message");

  if (!file) {
    message.textContent = "Please select a file.";
    return;
  }

  const formData = new FormData();
  formData.append("file", file);

  try {
    const response = await fetch("YOUR_API_GATEWAY_ENDPOINT/upload", {
      method: "POST",
      body: formData
    });

    if (!response.ok) {
      throw new Error("Upload failed with status: " + response.status);
    }

    const result = await response.json();
    message.textContent = "Upload successful: " + JSON.stringify(result);
  } catch (error) {
    console.error("Error:", error);
    message.textContent = "Upload failed. Check console for details.";
  }
}
