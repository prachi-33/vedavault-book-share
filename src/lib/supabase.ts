import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://iyolobflagtoetgclicf.supabase.co';
const supabaseAnonKey ="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5b2xvYmZsYWd0b2V0Z2NsaWNmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTcxOTkyOSwiZXhwIjoyMDY3Mjk1OTI5fQ.ANjWRuEXIIZ6HRAp9Iu8JsRKqoLw6J7mnsRs-GDWf8o";

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
