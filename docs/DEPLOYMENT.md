# Deploying to shinyapps.io

## Step 1: Sign Up for shinyapps.io

1. Go to https://www.shinyapps.io/
2. Click "Sign Up" and create a free account
3. Verify your email

## Step 2: Install Required Packages

```r
install.packages("rsconnect")
```

## Step 3: Authorize Your Account

In RStudio console:

```r
library(rsconnect)

# This will open a browser window to authorize
rsconnect::setAccountInfo(
  name = "YOUR_USERNAME",
  token = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)
```

You can find your token and secret in your shinyapps.io account settings under "Tokens".

## Step 4: Deploy the App

Make sure you're in the project directory, then:

```r
library(rsconnect)
rsconnect::deployApp("app.R")
```

Or if you're in RStudio with app.R open, click "Publish" button in the top-right.

## Step 5: Update GitHub Pages

Once deployed, note your app URL (usually `https://YOUR_USERNAME.shinyapps.io/healthcare-analytics/`)

Update the link in `docs/index.html`:

```html
<a href="https://YOUR_USERNAME.shinyapps.io/healthcare-analytics/" class="btn btn-primary" target="_blank">
    🚀 Launch Live Dashboard
</a>
```

## Step 6: Enable GitHub Pages

1. Go to your repository settings
2. Scroll to "GitHub Pages"
3. Under "Source", select "Deploy from a branch"
4. Select "main" branch and "/docs" folder
5. Click Save

Your site will be available at: `https://DevashreePawar.github.io/Healthcare-Data-Science-Project/`

## Notes

- shinyapps.io free tier has limits (25 active hours/month)
- For production, consider paid tier or self-hosting on DigitalOcean/AWS
- The GitHub Pages site is static but links to the live Shiny app
