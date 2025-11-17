# VedaVault Library Nexus - Setup Instructions

## Step 1: Run the SQL Schema

1. Open your Supabase dashboard at: https://iyolobflagtoetgclicf.supabase.co
2. Go to the **SQL Editor** section
3. Open the `supabase-schema.sql` file in this project
4. Copy all the SQL code and paste it into the SQL Editor
5. Click **Run** to execute the schema

This will create:
- All database tables (profiles, books, transactions, reviews, payments)
- Row Level Security (RLS) policies
- Triggers for automatic profile creation and book status updates
- Sample data (10 users with books and transactions)

## Step 2: Configure Email Settings (Optional but Recommended)

For testing purposes, disable email confirmation:

1. Go to **Authentication** > **Settings** in your Supabase dashboard
2. Scroll to **Email Auth**
3. **Disable** "Confirm email" (this allows instant signup during testing)

## Step 3: Test the Application

1. The app should now be running with authentication
2. Sign up with a test email (e.g., test@example.com)
3. You'll be able to:
   - Browse all books in the system
   - Add your own books
   - Request to borrow books
   - Approve/reject borrow requests
   - Track transactions

## Features Implemented

✅ User authentication with email/password
✅ Real-time book status updates
✅ Book management (add, view, delete)
✅ Borrowing workflow with approval system
✅ Transaction tracking
✅ Search and filter books
✅ Automatic status updates via database triggers
✅ Row Level Security for data protection

## Viewing Data in Supabase

You can view all your data directly in Supabase:

1. **Table Editor**: View and edit data in all tables
2. **Authentication**: See all registered users
3. **SQL Editor**: Run custom queries
4. **Realtime**: Monitor live changes to books table

## Next Steps

- Customize the design and colors in `src/index.css`
- Add more features like reviews, ratings, and QR codes
- Configure production email settings for real deployment
- Add user profile management
