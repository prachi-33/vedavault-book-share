import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/hooks/useAuth';
import { useNavigate } from 'react-router-dom';
import { Header } from '@/components/Header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { Search, BookOpen } from 'lucide-react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface Book {
  book_id: string;
  title: string;
  author: string;
  genre: string;
  status: 'available' | 'borrowed' | 'reserved';
  tags: string[];
  owner: {
    name: string;
    email: string;
  };
  borrower?: {
    name: string;
  };
}

const Index = () => {
  const { user, loading: authLoading } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [books, setBooks] = useState<Book[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!authLoading && !user) {
      navigate('/auth');
    }
  }, [user, authLoading, navigate]);

  useEffect(() => {
    if (user) {
      fetchBooks();
      subscribeToBookUpdates();
    }
  }, [user]);

  const fetchBooks = async () => {
    const { data, error } = await supabase
      .from('books')
      .select(`
        *,
        owner:profiles!books_owner_id_fkey (name, email),
        transactions!inner (
          borrower:profiles!transactions_borrower_id_fkey (name)
        )
      `)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching books:', error);
    } else {
      const booksWithBorrower = data?.map(book => ({
        ...book,
        borrower: book.status === 'borrowed' && book.transactions?.[0] 
          ? book.transactions[0].borrower 
          : undefined
      })) || [];
      setBooks(booksWithBorrower);
    }
    setLoading(false);
  };

  const subscribeToBookUpdates = () => {
    const channel = supabase
      .channel('books-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'books'
        },
        () => {
          fetchBooks();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const handleBorrowRequest = async (bookId: string) => {
    if (!user) return;

    const { error } = await supabase.from('transactions').insert({
      book_id: bookId,
      borrower_id: user.id,
      transaction_type: 'borrow',
      status: 'pending',
    });

    if (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to send borrow request',
      });
    } else {
      toast({
        title: 'Request Sent!',
        description: 'Your borrow request has been sent to the book owner',
      });
    }
  };

  const filteredBooks = books.filter(
    (book) =>
      book.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      book.author.toLowerCase().includes(searchTerm.toLowerCase()) ||
      book.genre?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      book.tags?.some((tag) => tag.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  if (authLoading || !user) {
    return null;
  }

  return (
    <>
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8 text-center">
          <h1 className="text-4xl font-bold mb-2 flex items-center justify-center gap-2">
            <BookOpen className="h-8 w-8 text-primary" />
            VedaVault Library Nexus
          </h1>
          <p className="text-muted-foreground">Share and borrow books with your community</p>
        </div>

        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search by title, author, genre, or tags..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        {loading ? (
          <p className="text-center text-muted-foreground">Loading books...</p>
        ) : filteredBooks.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <p className="text-muted-foreground">No books found</p>
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardHeader>
              <CardTitle>Available Books ({filteredBooks.length})</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Book Title</TableHead>
                    <TableHead>Author</TableHead>
                    <TableHead>Genre</TableHead>
                    <TableHead>Owner</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Borrower</TableHead>
                    <TableHead>Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredBooks.map((book) => (
                    <TableRow key={book.book_id}>
                      <TableCell className="font-medium">{book.title}</TableCell>
                      <TableCell>{book.author}</TableCell>
                      <TableCell>{book.genre || '-'}</TableCell>
                      <TableCell>{book.owner.name}</TableCell>
                      <TableCell>
                        <Badge
                          variant={book.status === 'available' ? 'default' : 'secondary'}
                        >
                          {book.status}
                        </Badge>
                      </TableCell>
                      <TableCell>{book.borrower?.name || '-'}</TableCell>
                      <TableCell>
                        {book.status === 'available' && book.owner.email !== user.email && (
                          <Button
                            size="sm"
                            onClick={() => handleBorrowRequest(book.book_id)}
                          >
                            Borrow
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        )}
      </div>
    </>
  );
};

export default Index;
