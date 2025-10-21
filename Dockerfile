# Use Node.js base image
FROM node:18

# Set working directory
WORKDIR /app

# Copy app code
COPY server.js .

# Expose app port
EXPOSE 80

# Run the app
CMD ["node", "server.js"]
