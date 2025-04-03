# Use the latest LTS version of Node.js on Alpine Linux
FROM node:lts-alpine

# Set environment variable for production
ENV NODE_ENV=production

# Set the working directory
WORKDIR /usr/app

# Copy only package files first (for better caching)
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]

# Install dependencies efficiently
RUN npm install --only=production --silent

# Copy the rest of the application files
COPY . .

# Set correct ownership (if needed)
RUN chown -R node /usr/app

# Use a non-root user for security
USER node

# Expose port 8080 (matching the app's running port)
EXPOSE 8080

# Define the command to run the application
CMD ["node", "app.js"]
