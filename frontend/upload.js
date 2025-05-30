async function uploadImage() {
  const input = document.getElementById('imageInput');
  const file = input.files[0];
  const message = document.getElementById('message');

  if (!file) {
    message.textContent = "Please select a file.";
    return;
  }

  const formData = new FormData();
  formData.append("file", file); // must match Lambda's field name

  try {
    const response = await fetch("https://solfnn8vw2.execute-api.us-east-1.amazonaws.com/prod/upload", {
      method: "POST",
      body: formData,
    });

    const text = await response.text();
    if (response.ok) {
      message.textContent = `✅ Success: ${text}`;
    } else {
      message.textContent = `❌ Error: ${text}`;
    }
  } catch (err) {
    console.error(err);
    message.textContent = "❌ Network error.";
  }
}
