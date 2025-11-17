import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://iyolobflagtoetgclicf.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5b2xvYmZsYWd0b2V0Z2NsaWNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQzNTM0NzYsImV4cCI6MjA0OTkyOTQ3Nn0.hKfOCPXjMbKJjOQcPkZfXJE-qjuWj6jl5TvSvWzSQxE';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
