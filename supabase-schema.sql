-- VedaVault Library Nexus Database Schema
-- Run this SQL in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create user profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  address TEXT,
  contact TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create books table
CREATE TABLE IF NOT EXISTS public.books (
  book_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  genre TEXT,
  isbn TEXT,
  tags TEXT[],
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'borrowed', 'reserved')),
  owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
  transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  book_id UUID REFERENCES public.books(book_id) ON DELETE CASCADE NOT NULL,
  borrower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  lend_date TIMESTAMP WITH TIME ZONE,
  return_date TIMESTAMP WITH TIME ZONE,
  due_date TIMESTAMP WITH TIME ZONE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('borrow', 'return')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  qr_code TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create reviews table
CREATE TABLE IF NOT EXISTS public.reviews (
  review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  book_id UUID REFERENCES public.books(book_id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create payments table
CREATE TABLE IF NOT EXISTS public.payments (
  payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID REFERENCES public.transactions(transaction_id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  payment_method TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Books policies
CREATE POLICY "Anyone can view available books" ON public.books FOR SELECT USING (true);
CREATE POLICY "Users can insert own books" ON public.books FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owners can update own books" ON public.books FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owners can delete own books" ON public.books FOR DELETE USING (auth.uid() = owner_id);

-- Transactions policies
CREATE POLICY "Users can view transactions they're involved in" ON public.transactions 
  FOR SELECT USING (
    auth.uid() = borrower_id OR 
    auth.uid() IN (SELECT owner_id FROM public.books WHERE book_id = transactions.book_id)
  );
CREATE POLICY "Users can create borrow requests" ON public.transactions 
  FOR INSERT WITH CHECK (auth.uid() = borrower_id);
CREATE POLICY "Book owners can update transactions" ON public.transactions 
  FOR UPDATE USING (
    auth.uid() IN (SELECT owner_id FROM public.books WHERE book_id = transactions.book_id)
  );

-- Reviews policies
CREATE POLICY "Anyone can view reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Users can create reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews" ON public.reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews" ON public.reviews FOR DELETE USING (auth.uid() = user_id);

-- Payments policies
CREATE POLICY "Users can view own payments" ON public.payments 
  FOR SELECT USING (
    auth.uid() IN (
      SELECT borrower_id FROM public.transactions WHERE transaction_id = payments.transaction_id
    ) OR
    auth.uid() IN (
      SELECT owner_id FROM public.books WHERE book_id IN (
        SELECT book_id FROM public.transactions WHERE transaction_id = payments.transaction_id
      )
    )
  );

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email
  );
  RETURN NEW;
END;
$$;

-- Create trigger for new user signups
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update book status when transaction is approved
CREATE OR REPLACE FUNCTION public.update_book_status_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    UPDATE public.books 
    SET status = 'borrowed', updated_at = NOW()
    WHERE book_id = NEW.book_id;
    
    NEW.lend_date = NOW();
    NEW.due_date = NOW() + INTERVAL '14 days';
  ELSIF NEW.status = 'completed' THEN
    UPDATE public.books 
    SET status = 'available', updated_at = NOW()
    WHERE book_id = NEW.book_id;
    
    NEW.return_date = NOW();
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for transaction status updates
DROP TRIGGER IF EXISTS on_transaction_status_change ON public.transactions;
CREATE TRIGGER on_transaction_status_change
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW 
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.update_book_status_on_transaction();

-- Seed sample data (10 users with 3-5 books each)
-- Note: You'll need to create actual auth users first, then update these IDs
INSERT INTO public.profiles (id, name, email, address, contact) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Alice Johnson', 'alice@vedavault.com', '123 Main St', '+1234567890'),
  ('00000000-0000-0000-0000-000000000002', 'Bob Smith', 'bob@vedavault.com', '456 Oak Ave', '+1234567891'),
  ('00000000-0000-0000-0000-000000000003', 'Carol White', 'carol@vedavault.com', '789 Pine Rd', '+1234567892'),
  ('00000000-0000-0000-0000-000000000004', 'David Brown', 'david@vedavault.com', '321 Elm St', '+1234567893'),
  ('00000000-0000-0000-0000-000000000005', 'Emma Davis', 'emma@vedavault.com', '654 Maple Dr', '+1234567894'),
  ('00000000-0000-0000-0000-000000000006', 'Frank Miller', 'frank@vedavault.com', '987 Cedar Ln', '+1234567895'),
  ('00000000-0000-0000-0000-000000000007', 'Grace Wilson', 'grace@vedavault.com', '147 Birch Ct', '+1234567896'),
  ('00000000-0000-0000-0000-000000000008', 'Henry Moore', 'henry@vedavault.com', '258 Spruce Way', '+1234567897'),
  ('00000000-0000-0000-0000-000000000009', 'Ivy Taylor', 'ivy@vedavault.com', '369 Willow Blvd', '+1234567898'),
  ('00000000-0000-0000-0000-000000000010', 'Jack Anderson', 'jack@vedavault.com', '741 Ash Pkwy', '+1234567899')
ON CONFLICT (id) DO NOTHING;

-- Sample books
INSERT INTO public.books (title, author, genre, isbn, tags, status, owner_id) VALUES
  ('The Great Gatsby', 'F. Scott Fitzgerald', 'Fiction', '9780743273565', ARRAY['classic', 'american'], 'available', '00000000-0000-0000-0000-000000000001'),
  ('To Kill a Mockingbird', 'Harper Lee', 'Fiction', '9780061120084', ARRAY['classic', 'legal'], 'available', '00000000-0000-0000-0000-000000000001'),
  ('1984', 'George Orwell', 'Dystopian', '9780451524935', ARRAY['classic', 'political'], 'borrowed', '00000000-0000-0000-0000-000000000001'),
  ('Pride and Prejudice', 'Jane Austen', 'Romance', '9780141439518', ARRAY['classic', 'romance'], 'available', '00000000-0000-0000-0000-000000000001'),
  
  ('The Hobbit', 'J.R.R. Tolkien', 'Fantasy', '9780547928227', ARRAY['fantasy', 'adventure'], 'available', '00000000-0000-0000-0000-000000000002'),
  ('Harry Potter', 'J.K. Rowling', 'Fantasy', '9780439708180', ARRAY['fantasy', 'magic'], 'borrowed', '00000000-0000-0000-0000-000000000002'),
  ('The Catcher in the Rye', 'J.D. Salinger', 'Fiction', '9780316769488', ARRAY['classic', 'coming-of-age'], 'available', '00000000-0000-0000-0000-000000000002'),
  
  ('Brave New World', 'Aldous Huxley', 'Dystopian', '9780060850524', ARRAY['classic', 'sci-fi'], 'available', '00000000-0000-0000-0000-000000000003'),
  ('The Lord of the Rings', 'J.R.R. Tolkien', 'Fantasy', '9780544003415', ARRAY['fantasy', 'epic'], 'available', '00000000-0000-0000-0000-000000000003'),
  ('Fahrenheit 451', 'Ray Bradbury', 'Dystopian', '9781451673319', ARRAY['sci-fi', 'censorship'], 'borrowed', '00000000-0000-0000-0000-000000000003'),
  ('Animal Farm', 'George Orwell', 'Political Fiction', '9780451526342', ARRAY['classic', 'allegory'], 'available', '00000000-0000-0000-0000-000000000003'),
  
  ('Dune', 'Frank Herbert', 'Science Fiction', '9780441013593', ARRAY['sci-fi', 'space'], 'available', '00000000-0000-0000-0000-000000000004'),
  ('Foundation', 'Isaac Asimov', 'Science Fiction', '9780553293357', ARRAY['sci-fi', 'series'], 'available', '00000000-0000-0000-0000-000000000004'),
  ('Neuromancer', 'William Gibson', 'Cyberpunk', '9780441569595', ARRAY['sci-fi', 'cyberpunk'], 'available', '00000000-0000-0000-0000-000000000004'),
  
  ('The Handmaids Tale', 'Margaret Atwood', 'Dystopian', '9780385490818', ARRAY['dystopian', 'feminist'], 'borrowed', '00000000-0000-0000-0000-000000000005'),
  ('Jane Eyre', 'Charlotte Bronte', 'Romance', '9780141441146', ARRAY['classic', 'gothic'], 'available', '00000000-0000-0000-0000-000000000005'),
  ('Wuthering Heights', 'Emily Bronte', 'Romance', '9780141439556', ARRAY['classic', 'gothic'], 'available', '00000000-0000-0000-0000-000000000005'),
  ('Sense and Sensibility', 'Jane Austen', 'Romance', '9780141439662', ARRAY['classic', 'romance'], 'available', '00000000-0000-0000-0000-000000000005'),
  
  ('Moby Dick', 'Herman Melville', 'Adventure', '9780142437247', ARRAY['classic', 'adventure'], 'available', '00000000-0000-0000-0000-000000000006'),
  ('War and Peace', 'Leo Tolstoy', 'Historical', '9780307266934', ARRAY['classic', 'historical'], 'available', '00000000-0000-0000-0000-000000000006'),
  ('The Odyssey', 'Homer', 'Epic', '9780140268867', ARRAY['classic', 'epic'], 'available', '00000000-0000-0000-0000-000000000006'),
  
  ('Crime and Punishment', 'Fyodor Dostoevsky', 'Psychological', '9780486415871', ARRAY['classic', 'psychological'], 'borrowed', '00000000-0000-0000-0000-000000000007'),
  ('The Brothers Karamazov', 'Fyodor Dostoevsky', 'Philosophical', '9780374528379', ARRAY['classic', 'philosophy'], 'available', '00000000-0000-0000-0000-000000000007'),
  ('Anna Karenina', 'Leo Tolstoy', 'Romance', '9780143035008', ARRAY['classic', 'romance'], 'available', '00000000-0000-0000-0000-000000000007'),
  ('The Idiot', 'Fyodor Dostoevsky', 'Philosophical', '9780375702242', ARRAY['classic', 'philosophy'], 'available', '00000000-0000-0000-0000-000000000007'),
  
  ('Catch-22', 'Joseph Heller', 'Satire', '9781451626650', ARRAY['satire', 'war'], 'available', '00000000-0000-0000-0000-000000000008'),
  ('Slaughterhouse-Five', 'Kurt Vonnegut', 'Science Fiction', '9780385333849', ARRAY['sci-fi', 'satire'], 'available', '00000000-0000-0000-0000-000000000008'),
  ('The Sun Also Rises', 'Ernest Hemingway', 'Fiction', '9780743297332', ARRAY['classic', 'modernist'], 'available', '00000000-0000-0000-0000-000000000008'),
  
  ('One Hundred Years of Solitude', 'Gabriel Garcia Marquez', 'Magical Realism', '9780060883287', ARRAY['magical-realism', 'classic'], 'available', '00000000-0000-0000-0000-000000000009'),
  ('The Alchemist', 'Paulo Coelho', 'Fiction', '9780062315007', ARRAY['inspirational', 'philosophy'], 'borrowed', '00000000-0000-0000-0000-000000000009'),
  ('Life of Pi', 'Yann Martel', 'Adventure', '9780156027328', ARRAY['adventure', 'survival'], 'available', '00000000-0000-0000-0000-000000000009'),
  ('The Kite Runner', 'Khaled Hosseini', 'Drama', '9781594631931', ARRAY['drama', 'afghanistan'], 'available', '00000000-0000-0000-0000-000000000009'),
  
  ('The Road', 'Cormac McCarthy', 'Post-Apocalyptic', '9780307387899', ARRAY['dystopian', 'survival'], 'available', '00000000-0000-0000-0000-000000000010'),
  ('Blood Meridian', 'Cormac McCarthy', 'Western', '9780679728757', ARRAY['western', 'historical'], 'available', '00000000-0000-0000-0000-000000000010'),
  ('All the Pretty Horses', 'Cormac McCarthy', 'Western', '9780679744399', ARRAY['western', 'romance'], 'available', '00000000-0000-0000-0000-000000000010');

-- Sample transactions
INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status, lend_date, due_date) 
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000002',
  'borrow',
  'approved',
  NOW() - INTERVAL '5 days',
  NOW() + INTERVAL '9 days'
FROM public.books b 
WHERE b.title = '1984' LIMIT 1;

INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status, lend_date, due_date)
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000003',
  'borrow',
  'approved',
  NOW() - INTERVAL '3 days',
  NOW() + INTERVAL '11 days'
FROM public.books b 
WHERE b.title = 'Harry Potter' LIMIT 1;

INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status, lend_date, due_date)
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000004',
  'borrow',
  'approved',
  NOW() - INTERVAL '7 days',
  NOW() + INTERVAL '7 days'
FROM public.books b 
WHERE b.title = 'Fahrenheit 451' LIMIT 1;

INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status, lend_date, due_date)
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000006',
  'borrow',
  'approved',
  NOW() - INTERVAL '10 days',
  NOW() + INTERVAL '4 days'
FROM public.books b 
WHERE b.title = 'The Handmaids Tale' LIMIT 1;

INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status, lend_date, due_date)
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000008',
  'borrow',
  'approved',
  NOW() - INTERVAL '2 days',
  NOW() + INTERVAL '12 days'
FROM public.books b 
WHERE b.title = 'Crime and Punishment' LIMIT 1;

INSERT INTO public.transactions (book_id, borrower_id, transaction_type, status)
SELECT 
  b.book_id,
  '00000000-0000-0000-0000-000000000010',
  'borrow',
  'pending'
FROM public.books b 
WHERE b.title = 'The Alchemist' LIMIT 1;

-- Enable realtime for books table (for real-time status updates)
ALTER PUBLICATION supabase_realtime ADD TABLE public.books;
ALTER TABLE public.books REPLICA IDENTITY FULL;
