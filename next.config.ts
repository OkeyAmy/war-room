import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
      {
        protocol: 'http',
        hostname: '**',
      },
    ],
  },
  // outputFileTracingRoot removed — was causing doubled path on Vercel (/vercel/path0/vercel/path0/)
  typescript: {
    ignoreBuildErrors: true,
  },


};

export default nextConfig;
// Orchids restart: 1772104642758
