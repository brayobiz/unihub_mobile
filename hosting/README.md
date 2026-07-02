# UniHub Static Hosting

This directory contains the static legal and informational pages for UniHub, deployed via Firebase Hosting.

## Folder Structure

- `public/`: Contains the static assets (HTML, CSS, images).
  - `index.html`: Home page.
  - `privacy.html`: Privacy Policy.
  - `terms.html`: Terms of Service.
  - `404.html`: Custom 404 page.
  - `style.css`: Main stylesheet.
  - `assets/`: Directory for images and other assets.

## Prerequisites

1.  **Firebase CLI**: Ensure you have the Firebase CLI installed.
    ```bash
    npm install -g firebase-tools
    ```
2.  **Login**: Log in to your Firebase account.
    ```bash
    firebase login
    ```

## Deployment Instructions

1.  Navigate to this directory:
    ```bash
    cd hosting
    ```
2.  (Optional) If not already connected, link to the project:
    ```bash
    firebase use unihub-mobile
    ```
3.  Deploy to Firebase Hosting:
    ```bash
    firebase deploy --only hosting
    ```

## Updating Legal Pages

To update the Privacy Policy or Terms of Service:
1.  Edit `public/privacy.html` or `public/terms.html`.
2.  Update the "Last Updated" date in the file.
3.  Run the deployment command again.

## Branding

- The branding follows a modern minimalist style using CSS variables in `style.css`.
- Add the UniHub logo to `public/assets/logo.png` and reference it in the HTML files if needed.
